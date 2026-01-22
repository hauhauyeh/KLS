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
        SalesRoute? GetByDateRoute(DateOnly? shipDate, string? shipRoute);

        IEnumerable<AssignTruck>? GetAssignTrucks(DateOnly shipDate);

        void SaveAssignTrucks(List<AssignTruck> assignTrucks);

        bool CheckZeroPrice(PrintInvoiceReq printInvoiceReq);
    }
}
