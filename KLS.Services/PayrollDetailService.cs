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

namespace KLS.Services
{
    //we use PayrollDetailService becuase of PayrollService class already there.
    public class PayrollDetailService : BaseService, IPayrollDetailService
    {
        private IWebHostEnvironment _hostingEnvironment;
        private readonly IDeleteLogService _deleteLogService;

        public PayrollDetailService(IUnitOfWork uow, IWebHostEnvironment hostingEnvironment, IDeleteLogService deleteLogService) : base(uow)
        {
            _hostingEnvironment = hostingEnvironment;
            _deleteLogService = deleteLogService;
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

        public void InjectEmp(PayrollInjectEmpReq injectEmpReq)
        {
            Uow.PayrollDetails.InjectEmp(injectEmpReq);
        }

        public void Inject(int vendorPaymentId)
        {
            Uow.PayrollDetails.Inject(vendorPaymentId);
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
    }
}
