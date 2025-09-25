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
    public class VendorPmtService : BaseService, IVendorPmtService
    {
        public VendorPmtService(IUnitOfWork uow) : base(uow)
        {

        }

        public PagingResponse<CheckRegister> GetCheckRegister(CheckRegisterReq checkRegisterReq)
        {
            var registerlist = Uow.VendorPmts.GetCheckRegister(checkRegisterReq);

            var totalRecords = Uow.VendorPmts.GetCheckRegister(checkRegisterReq).ToList().Count();

            return new PagingResponse<CheckRegister>(totalRecords, checkRegisterReq.Pageno, checkRegisterReq.Pagesize)
            {
                RowData = registerlist,
            };
        }
    }
}
