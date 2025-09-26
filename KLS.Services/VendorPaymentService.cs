using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class VendorPaymentService : BaseService, IVendorPaymentService
    {
        public VendorPaymentService(IUnitOfWork uow) : base(uow)
        {

        }

        public PagingResponse<CheckRegister> GetCheckRegister(CheckRegisterReq checkRegisterReq)
        {
            var registerlist = Uow.VendorPayments.GetCheckRegister(checkRegisterReq);

            var totalRecords = Uow.VendorPayments.GetCheckRegister(checkRegisterReq).ToList().Count();

            return new PagingResponse<CheckRegister>(totalRecords, checkRegisterReq.Pageno, checkRegisterReq.Pagesize)
            {
                RowData = registerlist,
            };
        }
    }
}
