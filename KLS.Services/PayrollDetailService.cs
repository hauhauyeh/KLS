using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Contract.Services;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Omu.ValueInjecter;

namespace KLS.Services
{
    //we use PayrollDetailService becuase of PayrollService class already there.
    public class PayrollDetailService : BaseService, IPayrollDetailService
    {
        private IWebHostEnvironment _hostingEnvironment;
        private readonly IDeleteLogService _deleteLogService;
        private readonly ITwilioService _twilioService;

        public PayrollDetailService(IUnitOfWork uow, IWebHostEnvironment hostingEnvironment, IDeleteLogService deleteLogService, ITwilioService twilioService) : base(uow)
        {
            _hostingEnvironment = hostingEnvironment;
            _deleteLogService = deleteLogService;
            _twilioService = twilioService;
        }

        public PagingResponse<PayrollList> GetPagedList(PayrollReq payrollReq)
        {
            var list = Uow.PayrollDetails.GetPagedList(payrollReq);

            var totalRecords = Uow.PayrollDetails.Count(payrollReq);

            return new PagingResponse<PayrollList>(totalRecords, payrollReq.Pageno, payrollReq.Pagesize)
            {
                RowData = list,
            };
        }

        public Payroll GetById(int vendorPaymentId)
        {
            var vendorPayment = Uow.VendorPayments.GetById(vendorPaymentId);

            Payroll payroll = new();
            payroll.InjectFrom(vendorPayment);

            var paycheck = Uow.PayrollDetails.Find(c => c.VendorPaymentId == vendorPaymentId).FirstOrDefault();

            payroll.PayPeriodStart = paycheck?.PayPeriodStart;
            payroll.PayPeriodEnd = paycheck?.PayPeriodEnd;
            return payroll;
        }

        public PayPeriod? InjectEmp(PayrollInjectEmpReq injectEmpReq)
        {
            Uow.PayrollDetails.InjectEmp(injectEmpReq);

            return Uow.Timesheets.GetPayPeriod(injectEmpReq.PayOption, injectEmpReq.PayDate, "Previous");
        }

        public void Inject(int vendorPaymentId)
        {
            Uow.PayrollDetails.Inject(vendorPaymentId);
        }

        public void SavePayroll(Payroll payroll)
        {
            Uow.PayrollDetails.SavePayroll(payroll);
        }

        public void Delete(int vendorPaymentId)
        {
            var payroll = Uow.VendorPayments.GetById(vendorPaymentId);

            if (payroll != null && !payroll.IsLocked)
            {
                Uow.VendorPayments.Find(c => c.VendorPaymentId == vendorPaymentId).ExecuteDelete();

                string docType = EnumHelper.DocType.Paycheck.ToString();

                _deleteLogService.Add(docType, vendorPaymentId);
            }
        }

        public ImportPayrollResp Import(IFormFile payrollFile)
        {
            var response = new ImportPayrollResp();

            if (payrollFile != null)
            {
                var excelfile = Path.Combine(_hostingEnvironment.WebRootPath, Constants.PayrollPath, payrollFile.FileName);

                GC.Collect();

                if (File.Exists(excelfile))
                    File.Delete(excelfile);

                using (var fileStream = new FileStream(excelfile, FileMode.Create))
                {
                    payrollFile.CopyTo(fileStream);
                }

                GC.Collect();

                response = Uow.PayrollDetails.ImportPayroll(excelfile);
            }

            return response;
        }

        public void VoidCheck(int vendorPaymentId)
        {
            Uow.PayrollDetails.VoidCheck(vendorPaymentId);
        }

        public void SendTextStmt(int vendorPaymentId)
        {
            var vendorPayment = Uow.VendorPayments.GetById(vendorPaymentId);
            if (vendorPayment == null)
                return;

            var paycheckDetail = Uow.PayrollDetails
                .Find(x => x.VendorPaymentId == vendorPaymentId)
                .FirstOrDefault();

            if (paycheckDetail == null)
                return;

            var payee = Uow.Payees.GetById(paycheckDetail.PayeeId);
            if (payee == null || string.IsNullOrWhiteSpace(payee.Phone1))
                return;

            var payeeName = payee.PayeeName ?? "Employee";
            var payPeriodStart = paycheckDetail.PayPeriodStart?.ToShortDateString() ?? "";
            var payPeriodEnd = paycheckDetail.PayPeriodEnd?.ToShortDateString() ?? "";
            var referenceId = vendorPayment.ReferenceId?.ToString() ?? "";

            string FormatCurrency(decimal? value) => string.Format("{0:C}", value ?? 0m);

            var message = new StringBuilder();
            message.AppendLine($"Hi {payeeName}, Your payroll period from {payPeriodStart}-{payPeriodEnd}");
            message.AppendLine($"CK#{referenceId}");
            message.AppendLine($"Gross:{FormatCurrency(paycheckDetail.GrossPay)}");
            message.AppendLine($"SS:{FormatCurrency(paycheckDetail.EmpOASDI)}");
            message.AppendLine($"Med:{FormatCurrency(paycheckDetail.EmpHI)}");
            message.AppendLine($"FWH:{FormatCurrency(paycheckDetail.EmpFWH)}");
            message.AppendLine($"Garn:{FormatCurrency(paycheckDetail.Garnishment)}");
            message.AppendLine($"CS:{FormatCurrency(paycheckDetail.ChildSup1)}");
            message.AppendLine($"Loan:{FormatCurrency(paycheckDetail.LoanRepayment)}");
            message.Append($"NETPAY:{FormatCurrency(paycheckDetail.NetPay)}");

            _twilioService.SendMessage(payee.Phone1, message.ToString());
        }

        public void UpdateReferenceId(PayrollUpdateReq updateReq)
        {
            var vendorPayment = Uow.VendorPayments.GetById(updateReq.VendorPaymentId);

            if (vendorPayment != null && !vendorPayment.IsLocked)
            {
                vendorPayment.ReferenceId = updateReq.ReferenceId;
                vendorPayment.UpdatedAt = DateTime.UtcNow;
                Uow.VendorPayments.Update(vendorPayment);
                Uow.Commit();
            }
        }
    }
}
