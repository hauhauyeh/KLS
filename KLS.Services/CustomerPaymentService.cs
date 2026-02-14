using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.EntityFrameworkCore;
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

        public CustomerPaymentService(IUnitOfWork uow,
            IDeleteLogService deleteLogService,
            IPDFService pdfService,
            IEmailService emailService,
            IEmailSettingService emailSettingService,
            ICompanyService companyService) : base(uow)
        {
            _deleteLogService = deleteLogService;
            _pdfService = pdfService;
            _emailService = emailService;
            _emailSettingService = emailSettingService;
            _companyService = companyService;
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

        public CustomerPayment GetById(int customerPaymentId)
        {
            return Uow.CustomerPayments.Find(c => c.CustomerPaymentId == customerPaymentId).Include(c => c.PaymentDetails).FirstOrDefault();
        }

        public CustomerPayment GetByIdWithInclude(int customerPaymentId)
        {
            return Uow.CustomerPayments.Find(c => c.CustomerPaymentId == customerPaymentId).Include(c => c.PaymentDetails).ThenInclude(s => s.Sales).FirstOrDefault();
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
                Uow.CustomerPayments.Find(c => c.CustomerPaymentId == customerPaymentId).ExecuteDelete();

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
                EmailReceipt(newPaymentId);

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
                                SentDate = DateTime.Now,
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
    }
}
