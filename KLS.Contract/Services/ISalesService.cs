using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ISalesService
    {
        PagingResponse<SalesList>? GetPagedList(SalesListReq salesListReq);

        Sales GetById(int salesId);

        Sales UpdateShipRoute(int salesId, string? shipRoute);

        void UpdateInstruction(int salesId, string? instruction);

        void UpdatePO(int salesId, string? custPO);

        void Delete(int salesId);

        ICollection<string?> GetShipRoutes(DateOnly shipDate);
    }
}
