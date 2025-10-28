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

        Sales UpdateShipRoute(int salesId, string? shipRoute);

        void UpdateInstruction(int salesId, string? instruction);

        void UpdatePO(int salesId, string? custPO);

        void DeleteSales(int salesId);

        ICollection<string?> GetShipRoutes(DateOnly shipDate);
    }
}
