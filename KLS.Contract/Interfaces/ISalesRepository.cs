using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface ISalesRepository : IRepository<Sales>
    {
        IQueryable<SalesList> GetAllSales(SalesListReq salesListReq);

        int CountAllSales(SalesListReq salesListReq);
    }
}
