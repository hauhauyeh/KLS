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
        IQueryable<SalesList> GetPagedList(SalesListReq salesListReq);

        int Count(SalesListReq salesListReq);

        void Inject(int salesId);

        int Checkout(SalesCheckoutReq checkoutReq);

        void UpdatePartially(int salesId);

        void UpdateNameDate(SalesUpdateReq updateReq);
    }
}
