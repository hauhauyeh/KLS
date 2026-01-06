using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface ITempSalesRepository : IRepository<TempSales>
    {
        IQueryable<TempSalesItem>? GetList(TempSalesReq tempReq);

        IQueryable<ItemSearch> Search(TempSalesReq tempReq);
    }
}
