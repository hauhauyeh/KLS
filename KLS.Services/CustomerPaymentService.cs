using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.EntityFrameworkCore;
using Square;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Transactions;
using static KLS.Common.EnumHelper;

namespace KLS.Services
{
    public class CustomerPaymentService : BaseService, ICustomerPaymentService
    {
        private static readonly string[] CustomerReturnReasonOptions =
        {
            "NSF Check",
            "ACH Return",
            "E-Check Return",
            "Card Dispute",
            "Stop Payment",
            "Bank Error"
        };

        private static readonly HashSet<string> AcceptedCustomerReturnReasons = new(StringComparer.OrdinalIgnoreCase)
        {
            "NSF Check",
            "ACH Return",
            "E-Check Return",
            "Card Dispute",
            "Stop Payment",
            "Bank Error",
            "NSF",
            "STOP",
            "DISPUTE",
            "BANK ERROR"
        };

        private readonly IDeleteLogService _deleteLogService;
        private readonly IPDFService _pdfService;
        private readonly IEmailService _emailService;
        private readonly IEmailSettingService _emailSettingService;
        private readonly ICompanyService _companyService;
        private readonly ISquareService _squareService;
        private readonly IMxMerchantService _mxMerchantService;
        private readonly ITwilioService _twilioService;

        public CustomerPaymentService(IUnitOfWork uow,
            IDeleteLogService deleteLogService,
            IPDFService pdfService,
            IEmailService emailService,
            IEmailSettingService emailSettingService,
            ICompanyService companyService,
            ISquareService squareService,
            IMxMerchantService mxMerchantService,
            ITwilioService twilioService) : base(uow)
        {
            _deleteLogService = deleteLogService;
            _pdfService = pdfService;
            _emailService = emailService;
            _emailSettingService = emailSettingService;
            _companyService = companyService;
            _squareService = squareService;
            _mxMerchantService = mxMerchantService;
            _twilioService = twilioService;
        }

        public PagingResponse<CustomerPaymentList> GetPagedList(CustomerPaymentReq customerPaymentReq)
        {
            var list = Uow.CustomerPayments.GetPagedList(customerPaymentReq);

            var totalRecords = Uow.CustomerPayments.Count(customerPaymentReq);

            return new PagingResponse<CustomerPaymentList>(totalRecords, customerPaymentReq.Pageno, customerPaymentReq.Pagesize)
            {
                RowData = list,
            };
        }

        public CustomerPayment? GetById(int customerPaymentId)
        {
            var payment = Uow.CustomerPayments.Find(c => c.CustomerPaymentId == customerPaymentId).Include(c => c.PaymentDetails).FirstOrDefault();
            NormalizePayment(payment);
            return payment;
        }

        public CustomerPayment? GetByIdWithInclude(int customerPaymentId)
        {
            var payment = Uow.CustomerPayments.Find(c => c.CustomerPaymentId == customerPaymentId)?.Include(c => c.Payee)?.Include(c => c.PaymentDetails!)?.ThenInclude(s => s.Sales).FirstOrDefault();
            NormalizePayment(payment);
            return payment;
        }

        public CustomerPaymentList? GetListById(int customerPaymentId)
        {
            var listReq = new CustomerPaymentReq
            {
                Id = customerPaymentId
            };

            return Uow.CustomerPayments.GetPagedList(listReq).AsEnumerable().FirstOrDefault();
        }

        public void Delete(int customerPaymentId)
        {
            var eligibility = Uow.CustomerPayments.GetEditEligibility(customerPaymentId);
            if (!eligibility.CanEdit)
                throw new ValidationException("This payment cannot be deleted because future payments still depend on it.");

            var payment = Uow.CustomerPayments.GetById(customerPaymentId);

            if (payment != null && !payment.IsLocked)
            {
                Uow.CustomerPayments.Delete(customerPaymentId);

                string docType = EnumHelper.DocType.CustomerPayment.ToString();

                _deleteLogService.Add(docType, customerPaymentId);
            }
        }

        public void UpdateNotes(CustomerPaymentUpdateReq updateReq)
        {
            Uow.CustomerPayments.Find(c => c.CustomerPaymentId == updateReq.CustomerPaymentId).ExecuteUpdate(setters => setters
            .SetProperty(x => x.Notes, x => updateReq.Notes)
            .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));
        }

        public CustomerPaymentList Save(CustomerPaymentSaveReq paymentSaveReq)
        {
            var newPaymentId = Uow.CustomerPayments.Save(paymentSaveReq);

            if (paymentSaveReq.CustomerPaymentId == 0)
            {
                EmailReceipt(newPaymentId);
                SendMessage(newPaymentId);
            }

            return GetListById(newPaymentId);
        }

        public List<string> GetReturnTypes()
        {
            return CustomerReturnReasonOptions.ToList();
        }

        public void SaveReturn(CustomerPaymentReturnReq returnReq)
        {
            var payment = Uow.CustomerPayments.GetById(returnReq.CustomerPaymentId);
            if (payment == null)
                throw new Exception("Customer payment not found.");

            var method = payment.PaymentMethod?.Trim().Replace("-", "_").Replace(" ", "_").ToUpperInvariant();
            var allowed = new[]
            {
                EnumPaymentMethod.CHECK.ToString(),
                EnumPaymentMethod.HANDWRITE_CHECK.ToString(),
                EnumPaymentMethod.ACH.ToString(),
                EnumPaymentMethod.E_CHECK.ToString(),
                EnumPaymentMethod.CREDIT_CARD.ToString()
            };

            if (string.IsNullOrWhiteSpace(method) || !allowed.Contains(method))
                throw new Exception($"Payment method {payment.PaymentMethod ?? "(blank)"} can not be marked as returned.");

            if (string.IsNullOrWhiteSpace(returnReq.ReturnType) || !AcceptedCustomerReturnReasons.Contains(returnReq.ReturnType.Trim()))
                throw new Exception($"Return reason {returnReq.ReturnType ?? "(blank)"} is not supported.");

            Uow.CustomerPayments.SaveReturn(returnReq);
        }

        public void DeleteReturn(int customerPaymentId)
        {
            Uow.CustomerPayments.DeleteReturn(customerPaymentId);
        }

        public IEnumerable<CustomerPaymentStatement>? Statement(int payeeId)
        {
            return Uow.CustomerPayments.Statement(payeeId);
        }

        public IEnumerable<RefundQueueRow> GetRefundQueue()
        {
            var payments = Uow.CustomerPayments.GetAll();
            var payees = Uow.Payees.GetAll();

            return Uow.CustomerPaymentDetails.GetAll()
                .Where(pd => pd.DetailRole == "AsRefund"
                    && pd.SourceCustomerPaymentId == pd.CustomerPaymentId
                    && pd.RefundPaymentId == null
                    && (pd.PaymentApplied ?? 0) > 0)
                .Join(payments,
                    pd => pd.CustomerPaymentId,
                    cp => cp.CustomerPaymentId,
                    (pd, cp) => new { pd, cp })
                .Join(payees,
                    x => x.cp.PayeeId,
                    p => p.PayeeId,
                    (x, p) => new RefundQueueRow
                    {
                        PaymentDetailId = x.pd.PaymentDetailId,
                        CustomerPaymentId = x.cp.CustomerPaymentId,
                        PayeeId = x.cp.PayeeId,
                        PayeeName = p.PayeeName,
                        SourcePaymentNumber = x.cp.PaymentNumber,
                        PaymentDate = x.cp.PaymentDate,
                        ReservedAmount = x.pd.PaymentApplied ?? 0,
                        ReferenceId = x.cp.ReferenceId,
                        Notes = x.cp.Notes
                    })
                .OrderByDescending(x => x.PaymentDate)
                .ThenByDescending(x => x.SourcePaymentNumber)
                .ToList();
        }

        public CustomerPaymentList IssueRefund(IssueRefundReq issueRefundReq)
        {
            if (issueRefundReq.PaymentDetailId <= 0)
                throw new ValidationException("Refund source is required.");

            if (!issueRefundReq.PaymentDate.HasValue)
                throw new ValidationException("Refund date is required.");

            if (string.IsNullOrWhiteSpace(issueRefundReq.PaymentMethod))
                throw new ValidationException("Refund method is required.");

            if (!issueRefundReq.FromAccountId.HasValue || issueRefundReq.FromAccountId <= 0)
                throw new ValidationException("From account is required.");

            var refundSource = Uow.CustomerPaymentDetails.Find(x => x.PaymentDetailId == issueRefundReq.PaymentDetailId)
                .FirstOrDefault();

            if (refundSource == null
                || refundSource.DetailRole != "AsRefund"
                || refundSource.SourceCustomerPaymentId != refundSource.CustomerPaymentId)
                throw new ValidationException("Refund source was not found.");

            if (refundSource.RefundPaymentId.HasValue)
                throw new ValidationException("This refund was already issued.");

            var refundAmount = refundSource.PaymentApplied ?? 0m;

            if (refundAmount <= 0)
                throw new ValidationException("Refund amount must be greater than 0.");

            var sourcePayment = Uow.CustomerPayments.Find(x => x.CustomerPaymentId == refundSource.CustomerPaymentId)
                .FirstOrDefault();

            if (sourcePayment == null)
                throw new ValidationException("Source payment was not found.");

            var vendorPayment = new VendorPayment
            {
                VendorPaymentId = 0,
                PayeeId = sourcePayment.PayeeId,
                PaymentDate = issueRefundReq.PaymentDate,
                PaymentType = "Customer Refund",
                PaymentMethod = issueRefundReq.PaymentMethod?.Trim(),
                FromAccountId = issueRefundReq.FromAccountId,
                ReferenceId = issueRefundReq.ReferenceId,
                PaymentAmount = refundAmount,
                Notes = issueRefundReq.Notes
            };

            int vendorPaymentId;

            using (var scope = new TransactionScope(TransactionScopeOption.Required, TransactionScopeAsyncFlowOption.Enabled))
            {
                vendorPaymentId = Uow.VendorPayments.Save(vendorPayment);

                Uow.CustomerPaymentDetails.Find(x => x.PaymentDetailId == issueRefundReq.PaymentDetailId)
                    .ExecuteUpdate(setters => setters
                        .SetProperty(x => x.RefundPaymentId, x => vendorPaymentId)
                        .SetProperty(x => x.RefundedAt, x => DateTime.UtcNow));

                scope.Complete();
            }

            return GetListById(sourcePayment.CustomerPaymentId);
        }

        public CustomerPaymentEditEligibility GetEditEligibility(int customerPaymentId)
        {
            return Uow.CustomerPayments.GetEditEligibility(customerPaymentId);
        }

        private void EmailReceipt(int customerPaymentId)
        {
            var payment = GetByIdWithInclude(customerPaymentId);

            if (payment != null)
            {
                string normalized = payment.PaymentMethod?.Trim().Replace(" ", "_").Replace("-", "_").ToUpper();

                if (normalized == EnumPaymentMethod.E_CHECK.ToString() || normalized == EnumPaymentMethod.CREDIT_CARD.ToString())
                {
                    var payee = Uow.Payees.GetById(payment.PayeeId);
                    var toEmails = payee.EmailACH;

                    if (!string.IsNullOrEmpty(toEmails))
                    {
                        var emailReceipt = new EmailReceipt
                        {
                            Payment = payment,
                            Payee = payee,
                            Company = _companyService.GetDefault()
                        };

                        string subject = "Payment Receipt " + payee.PayeeName;
                        string mailBody = _pdfService.RenderTemplate("~/Views/PaymentReceipt.cshtml", emailReceipt);

                        var setting = _emailSettingService.GetSetting();

                        Task.Factory.StartNew(() => _emailService.SendEmail(setting, toEmails, subject, mailBody, null), TaskCreationOptions.LongRunning).ContinueWith((t) =>
                        {
                            var log = new EmailLog
                            {
                                PayeeId = payee.PayeeId,
                                Email = toEmails,
                                SentDate = DateTime.UtcNow,
                                EventType = EnumHelper.EmailLogEvent.ACHReceipt.ToString(),
                                ErrorMessage = t.Result,
                                Status = string.IsNullOrEmpty(t.Result)
                            };

                            Uow.EmailLogs.Add(log);
                            Uow.Commit();
                        });
                    }
                }
            }
        }

        public void SendMessage(int customerPaymentId)
        {
            var payment = GetById(customerPaymentId);
            var cust = Uow.Customers.GetById(payment.PayeeId);
            var payee = Uow.Payees.GetById(payment.PayeeId);

            if (!string.IsNullOrEmpty(cust.TextACH))
            {
                string msgBody;

                if (payment.PaymentMethod == "ACH")
                {
                    var companyName = _companyService.GetDefault().CompanyName;

                    msgBody = "Dear " + payee.PayeeName + "! " + string.Format("{0:c}", payment.PaymentAmount) + " will be deduct from your last 4 Account #" + payment.Last4 + " at " + companyName + " on " + string.Format("{0:d}", payment.PaymentDate.Value.AddDays(1));
                }
                else
                {
                    msgBody = "Dear " + payee.PayeeName + "! Thank you for your payment. Your pmt #" + payment.PaymentNumber + " of total " + string.Format("{0:c}", payment.PaymentAmount) + " with ref #" + payment.ReferenceId;
                }

                _twilioService.SendMessage(cust.TextACH, msgBody);
            }
        }

        public CustomerPayment ChargePayment(PaymentChargeReq chargeReq)
        {
            try
            {
                decimal dueTotal = GetDueTotal(chargeReq.SalesIds);
                decimal ccFee = Utilities.Rounding(chargeReq.CCFeePercent * dueTotal, 2) ?? 0m;
                decimal paymentAmount = dueTotal + ccFee;
                long paymentAmountCent = Convert.ToInt64(paymentAmount * 100m);

                CreateGatewayPaymentReq paymentReq = null;

                if (chargeReq.PaymentMethodId.HasValue)
                {
                    var method = Uow.PaymentMethods.GetById(chargeReq.PaymentMethodId.Value);

                    if (method == null)
                        throw new Exception("Payment method not found.");

                    if (method.IsACH)
                    {
                        var mxResp = _mxMerchantService
                            .ChargeAsync(method, dueTotal, true)
                            .GetAwaiter()
                            .GetResult();

                        var referenceId = ExtractMxReferenceId(mxResp);

                        paymentReq = new CreateGatewayPaymentReq
                        {
                            PayeeId = chargeReq.PayeeId,
                            PaymentMethod = "ACH",
                            ReferenceId = referenceId,
                            PaymentAmount = dueTotal,
                            SalesIds = chargeReq.SalesIds,
                            Gateway = "MX Merchant",
                            CCFee = 0m,
                            CardType = null,
                            Last4 = method.Last4
                        };
                    }
                    else
                    {
                        var paymentResponse = _squareService
                            .ChargePayment(chargeReq.PayeeId, method.SQCustId, method.SQCardId, paymentAmountCent)
                            .GetAwaiter()
                            .GetResult();

                        ValidateSquareResponse(paymentResponse);

                        paymentReq = new CreateGatewayPaymentReq
                        {
                            PayeeId = chargeReq.PayeeId,
                            PaymentMethod = "CREDIT CARD",
                            ReferenceId = paymentResponse.Payment?.Id,
                            PaymentAmount = dueTotal + ccFee,
                            SalesIds = chargeReq.SalesIds,
                            Gateway = "Square Payment",
                            CCFee = ccFee,
                            CardType = Convert.ToString(paymentResponse.Payment?.CardDetails?.Card?.CardBrand),
                            Last4 = Convert.ToString(paymentResponse.Payment?.CardDetails?.Card?.Last4)
                        };
                    }
                }
                else if (!string.IsNullOrWhiteSpace(chargeReq.SqToken))
                {
                    //if payment amount change dont applied to invoice just save payment
                    if (chargeReq.IsPaymentChange)
                    {
                        chargeReq.SalesIds = "";

                        ccFee = Utilities.Rounding(chargeReq.CCFeePercent * chargeReq.PaymentAmount, 2) ?? 0m;
                        paymentAmount = chargeReq.PaymentAmount + ccFee;
                        paymentAmountCent = Convert.ToInt64(paymentAmount * 100m);
                    }

                    var paymentResponse = _squareService
                        .ChargePayment(chargeReq.PayeeId, null, chargeReq.SqToken, paymentAmountCent)
                        .GetAwaiter()
                        .GetResult();

                    ValidateSquareResponse(paymentResponse);

                    paymentReq = new CreateGatewayPaymentReq
                    {
                        PayeeId = chargeReq.PayeeId,
                        PaymentMethod = "CREDIT CARD",
                        ReferenceId = paymentResponse?.Payment.Id,
                        PaymentAmount = paymentAmount,
                        SalesIds = chargeReq.SalesIds,
                        Gateway = "Square Payment",
                        CCFee = ccFee,
                        CardType = Convert.ToString(paymentResponse?.Payment?.CardDetails?.Card?.CardBrand),
                        Last4 = Convert.ToString(paymentResponse?.Payment?.CardDetails?.Card?.Last4)
                    };
                }
                else if (chargeReq.PaymentMethod != null)
                {
                    //if payment amount change dont applied to invoice just save payment
                    if (chargeReq.IsPaymentChange)
                    {
                        chargeReq.SalesIds = "";

                        ccFee = Utilities.Rounding(chargeReq.CCFeePercent * chargeReq.PaymentAmount, 2) ?? 0m;
                        paymentAmount = chargeReq.PaymentAmount + ccFee;
                    }

                    var isAch = chargeReq.PaymentMethod.IsACH;

                    // For new card, include ccFee in payment amount
                    if (!isAch && !chargeReq.IsPaymentChange)
                        paymentAmount = dueTotal + ccFee;

                    var mxResp = _mxMerchantService
                           .ChargeAsync(chargeReq.PaymentMethod, paymentAmount, false)
                           .GetAwaiter()
                           .GetResult();

                    var referenceId = ExtractMxReferenceId(mxResp);
                    var last4 = Utilities.GetLast4(chargeReq.PaymentMethod.AccountNumber);

                    paymentReq = new CreateGatewayPaymentReq
                    {
                        PayeeId = chargeReq.PayeeId,
                        PaymentMethod = isAch ? "ACH" : "CREDIT CARD",
                        ReferenceId = referenceId,
                        PaymentAmount = paymentAmount,
                        SalesIds = chargeReq.SalesIds,
                        Gateway = "MX Merchant",
                        CCFee = isAch ? 0m : ccFee,
                        CardType = isAch ? null : chargeReq.PaymentMethod.AccountType,
                        Last4 = last4
                    };
                }
                else
                {
                    throw new Exception("Payment method or Square token is required.");
                }

                var paymentId = Uow.CustomerPayments.SaveGatewayPayment(paymentReq);

                EmailReceipt(paymentId);
                SendMessage(paymentId);

                return Uow.CustomerPayments.GetById(paymentId);
            }
            catch
            {
                throw;
            }
        }

        public decimal GetDueTotal(string salesIds)
        {
            if (string.IsNullOrWhiteSpace(salesIds))
                return 0m;

            var ids = salesIds
                .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Select(s => int.TryParse(s, out var id) ? (int?)id : null)
                .Where(id => id.HasValue)
                .Select(id => id!.Value)
                .Distinct()
                .ToArray();

            if (ids.Length == 0)
                return 0m;

            return Uow.Sales.GetAll()
                .Where(x => ids.Contains(x.SalesId))
                .Sum(x => (decimal?)(x.AmountDue ?? 0m)) ?? 0m;
        }


        public CustomerPaymentView? GetDetails(int paymentId)
        {
            var payment = GetByIdWithInclude(paymentId);

            if (payment == null) return null;

            return new CustomerPaymentView
            {
                CustomerPayment = new CustomerPaymentDto
                {
                    CustomerPaymentId = payment.CustomerPaymentId,
                    PaymentNumber = payment.PaymentNumber,
                    PaymentType = payment.PaymentType,
                    PayeeId = payment.PayeeId,
                    PayeeName = payment.Payee?.PayeeName,
                    PaymentDate = payment.PaymentDate,
                    PaymentMethod = payment.PaymentMethod,
                    ReferenceId = payment.ReferenceId,
                    PaymentAmount = payment.PaymentAmount,
                    PaymentApplied = payment.PaymentApplied,
                    UnappliedAmount = payment.UnappliedAmount,
                    Notes = payment.Notes,
                    IsLocked = payment.IsLocked,
                    IsReturned = payment.IsReturned
                },
                CustomerPaymentDetails = payment.PaymentDetails?.Select(d => new CustomerPaymentDetailDto
                {
                    PaymentDetailId = d.PaymentDetailId,
                    CustomerPaymentId = d.CustomerPaymentId,
                    SalesId = d.SalesId,
                    PaymentApplied = d.PaymentApplied,
                    PaymentDiscount = d.PaymentDiscount,
                    ShortDiscount = d.ShortDiscount,
                    OtherDiscount = d.OtherDiscount,
                    SalesNumber = d.Sales?.SalesNumber ?? 0
                }).ToList()
            };
        }

        private static void NormalizePaymentType(CustomerPayment? payment)
        {
            if (payment?.PaymentType == "Bad Debit")
            {
                payment.PaymentType = "Bad Debt";
            }
        }

        private void NormalizePayment(CustomerPayment? payment)
        {
            NormalizePaymentType(payment);

            if (payment == null) return;

            var refundAmount = payment.PaymentDetails?
                .Where(d => d.DetailRole == "AsRefund"
                    && d.SourceCustomerPaymentId == payment.CustomerPaymentId)
                .Sum(d => (decimal?)d.PaymentApplied) ?? 0m;

            var ccFeeAmount = payment.PaymentDetails?
                .Where(d => d.DetailRole == "CCFee")
                .Sum(d => (decimal?)d.PaymentApplied) ?? 0m;
            var isCreditCardPayment = string.Equals(payment.PaymentMethod, "CREDIT CARD", StringComparison.OrdinalIgnoreCase);

            if (refundAmount > 0)
            {
                payment.ExtraDisposition = "Refund";
                payment.ExtraDispositionAmount = refundAmount;
                return;
            }

            // A persisted CCFee row on a credit-card payment means the leftover was
            // explicitly disposed as CC fee. Treat that as its own first-class
            // disposition on reload/edit so the UI can reopen the payment in the
            // same disposition the user originally chose.
            if (isCreditCardPayment && ccFeeAmount > 0)
            {
                payment.ExtraDisposition = "CCFee";
                payment.ExtraDispositionAmount = ccFeeAmount;
                return;
            }

            if ((payment.AsIncome ?? 0) > 0)
            {
                payment.ExtraDisposition = "Income";
                payment.ExtraDispositionAmount = payment.AsIncome;
                return;
            }

            if ((payment.UnappliedAmount ?? 0) > 0)
            {
                payment.ExtraDisposition = "Credit";
                payment.ExtraDispositionAmount = payment.UnappliedAmount;
            }
        }


        private static void ValidateSquareResponse(CreatePaymentResponse paymentResponse)
        {
            if (paymentResponse?.Payment == null)
                throw new Exception("Payment gateway returned an empty response.");

            // Square statuses can be: APPROVED, COMPLETED, CANCELED, FAILED, PENDING, etc.
            // Your original requirement: must be COMPLETED
            if (!string.Equals(paymentResponse.Payment.Status, "COMPLETED", StringComparison.OrdinalIgnoreCase))
            {
                var errorMsg = paymentResponse.Errors != null && paymentResponse.Errors.Any()
                    ? string.Join(" | ", paymentResponse.Errors.Select(e => $"{e.Code}: {e.Detail}"))
                    : $"Payment was not completed. Status: {paymentResponse.Payment.Status}";

                throw new Exception(errorMsg);
            }
        }

        private static string ExtractMxReferenceId(MxCreatePaymentResponse mxResp)
        {
            if (mxResp == null || mxResp.Extra.Count == 0) return "";

            string? TryGet(string key)
                => mxResp.Extra
                    .FirstOrDefault(kv => string.Equals(kv.Key, key, StringComparison.OrdinalIgnoreCase))
                    .Value?.ToString();

            return
                TryGet("id")
                ?? TryGet("reference")
                ?? TryGet("referenceNumber")
                ?? "";
        }

    }
}
