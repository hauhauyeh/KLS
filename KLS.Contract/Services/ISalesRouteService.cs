using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ISalesRouteService
    {
        SalesRoute Create(SalesRoute salesRoute);

        void UpdateInvoice(SalesRoute salesRoute);

        void UpdateDriverSheet(SalesRoute salesRoute);

        SalesRoute? GetByDateRoute(DateOnly? shipDate, string? shipRoute);

        IEnumerable<AssignTruck>? GetAssignTrucks(DateOnly shipDate);

        void SaveAssignTrucks(List<AssignTruck> assignTrucks);

        void SyncByDate(DateOnly shipDate);

        bool CheckZeroPrice(PrintInvoiceReq printInvoiceReq);
    }
}
