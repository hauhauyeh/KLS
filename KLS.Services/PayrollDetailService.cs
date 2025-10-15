using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Hosting.Internal;
using Org.BouncyCastle.Ocsp;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
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

        public void InjectPayrollDetail(int vendorPaymentId)
        {
            Uow.PayrollDetails.InjectPayrollDetail(vendorPaymentId);
        }

        public ImportPayrollResp Import(IFormFile PayrollFile)
        {
            var response = new ImportPayrollResp();

            if (PayrollFile != null)
            {
                var excelfile = Path.Combine(_hostingEnvironment.WebRootPath, Constants.PayrollPath, PayrollFile.FileName);

                GC.Collect();

                if (System.IO.File.Exists(excelfile))
                    System.IO.File.Delete(excelfile);

                using (var fileStream = new FileStream(excelfile, FileMode.Create))
                {
                    PayrollFile.CopyTo(fileStream);
                }

                GC.Collect();

                response = Uow.PayrollDetails.ImportPayroll(excelfile);
            }

            return response;
        }
    }
}
