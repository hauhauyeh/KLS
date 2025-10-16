using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Hosting.Internal;
using Org.BouncyCastle.Ocsp;
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

        public PayrollDetailService(IUnitOfWork uow, IWebHostEnvironment hostingEnvironment) : base(uow)
        {
            _hostingEnvironment = hostingEnvironment;
        }

        public PagingResponse<PayrollList> GetAllPayrolls(PayrollReq payrollReq)
        {
            var payrolllist = Uow.PayrollDetails.GetAllPayrolls(payrollReq);

            var totalRecords = Uow.PayrollDetails.CountAllPayrolls(payrollReq);

            return new PagingResponse<PayrollList>(totalRecords, payrollReq.Pageno, payrollReq.Pagesize)
            {
                RowData = payrolllist,
            };
        }

        public void InjectPayrollEmp(PayrollInjectEmpReq injectEmpReq)
        {
            Uow.PayrollDetails.InjectPayrollEmp(injectEmpReq);
        }

        public void InjectPayroll(int vendorPaymentId)
        {
            Uow.PayrollDetails.InjectPayroll(vendorPaymentId);
        }

        public void DeletePayroll(int vendorPaymentId)
        {
            var payroll = Uow.VendorPayments.GetById(vendorPaymentId);

            if (payroll != null && !payroll.IsLocked)
            {
                Uow.VendorPayments.Find(c => c.VendorPaymentId == vendorPaymentId).ExecuteDelete();
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
    }
}
