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
    public class SalesService : BaseService, ISalesService
    {
        public SalesService(IUnitOfWork uow) : base(uow)
        {

        }

        public PagingResponse<SalesList> GetAllSales(SalesListReq salesListReq)
        {
            var sales = Uow.Sales.GetAllSales(salesListReq);

            var totalRecords = Uow.Sales.CountAllSales(salesListReq);

            return new PagingResponse<SalesList>(totalRecords, salesListReq.Pageno, salesListReq.Pagesize)
            {
                RowData = sales,
            };
        }

        public Sales GetById(int salesId)
        {
            return Uow.Sales.GetById(salesId);
        }
    }
}
