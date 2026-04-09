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
using static KLS.Common.EnumHelper;

namespace KLS.Services
{
    public class CustomerPaymentService : BaseService, ICustomerPaymentService
    {
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
            return Uow.CustomerPayments.Find(c => c.CustomerPaymentId == customerPaymentId).Include(c => c.PaymentDetails).FirstOrDefault();
        }

        public CustomerPayment? GetByIdWithInclude(int customerPaymentId)
        {
            return Uow.CustomerPayments.Find(c => c.CustomerPaymentId == customerPaymentId)?.Include(c => c.Payee)?.Include(c => c.PaymentDetails!)?.ThenInclude(s => s.Sales).FirstOrDefault();
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
            var types = new List<string>();

            foreach (var enumValue in Enum.GetValues<EnumHelper.ReturnTypes>())
            {
                var field = enumValue.GetType().GetField(enumValue.ToString());

                if (Attribute.GetCustomAttribute(field, typeof(DisplayAttribute)) is DisplayAttribute attribute)
                {
                    types.Add(attribute.Name);
                }
            }

            return types;
        }

        public void SaveReturn(CustomerPaymentReturnReq returnReq)
        {
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
            if (mxResp == null) return "";

            // Try common keys
            string? TryGet(string key)
                => mxResp.Extra.TryGetValue(key, out var v) ? v?.ToString() : null;

            return
                TryGet("id")
                ?? TryGet("paymentId")
                ?? TryGet("transactionId")
                ?? TryGet("referenceId")
                ?? "";
        }

    }
}
