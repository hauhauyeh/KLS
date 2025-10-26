using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface ISalesService
    {
        PagingResponse<SalesList>? GetAllSales(SalesListReq salesListReq);

        Sales GetById(int salesId);
    }
}
