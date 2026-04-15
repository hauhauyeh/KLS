using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ISalesRouteDetailService
    {
        IEnumerable<SalesRouteDetail>? GetList(int salesRouteId);

        IEnumerable<SalesRouteDetail>? GetList(DateOnly shipDate, string? shipRoute);

        IEnumerable<SalesRouteDetail>? GetPendingUntracked();

        SalesRouteDetail GetById(int detailId);

        SalesRouteDetail Create(SalesRouteDetail routeDetail);

        SalesRouteDetail Update(SalesRouteDetail routeDetail);

        SalesRouteDetail UpdateUnit(SalesRouteDetail routeDetail);

        SalesRouteDetail Restock(int detailId);

        void Delete(int detailId);
    }
}
