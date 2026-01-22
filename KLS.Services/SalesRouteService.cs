using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class SalesRouteService : BaseService, ISalesRouteService
    {
        private readonly ITruckService _truckService;

        public SalesRouteService(IUnitOfWork uow, ITruckService truckService) : base(uow)
        {
            _truckService = truckService;
        }

        public SalesRoute? GetByDateRoute(DateOnly? shipDate, string? shipRoute)
        {
            return Uow.SalesRoutes.Find(c => c.ShipDate == shipDate && c.ShipRoute == shipRoute).FirstOrDefault();
        }

        public IEnumerable<AssignTruck>? GetAssignTrucks(DateOnly shipDate)
        {
            var trucks = _truckService.GetActive().ToList();

            var assignRoutes = Uow.SalesRoutes.Find(c => c.ShipDate == shipDate).OrderBy(c => c.SalesRouteId).ToList();

            // Group routes by truck number
            var routeLookup = assignRoutes?
                .GroupBy(r => r.TruckNumber)
                .ToDictionary(g => g.Key, g => g.ToList());

            var assignTrucks = trucks
           .Select(truck =>
           {
               routeLookup.TryGetValue(truck.TruckNumber, out var routes);

               return new AssignTruck
               {
                   TruckNumber = truck.TruckNumber,
                   Routes = routes,
                   DriverName = routes?.FirstOrDefault()?.Driver
               };
           })

           // Sort by SalesRouteId first, then TruckNumber
           .OrderBy(at => at.Routes?.FirstOrDefault()?.SalesRouteId ?? int.MaxValue)
           .ThenBy(at => at.TruckNumber)
           .ToList();

            return assignTrucks;
        }

        public void SaveAssignTrucks(List<AssignTruck> assignTrucks)
        {
            if (assignTrucks == null || assignTrucks.Count == 0)
                return;

            var incoming = assignTrucks
                .Where(t => t.Routes != null && t.Routes.Count > 0)
                .SelectMany(t => t.Routes!.Select(r => new SalesRoute
                {
                    ShipDate = r.ShipDate,
                    ShipRoute = (r.ShipRoute ?? "").Trim(),
                    Driver = r.Driver,
                    TruckNumber = t.TruckNumber
                }))
               .Where(r => !string.IsNullOrWhiteSpace(r.ShipRoute))
               .ToList();

            if (incoming.Count == 0)
                return;

            var shipDate = incoming[0].ShipDate;

            // Always delete all existing rows for that day
            var existing = Uow.SalesRoutes.Find(sr => sr.ShipDate == shipDate).ToList();

            foreach (var row in existing)
                Uow.SalesRoutes.RemoveById(row.SalesRouteId);

            // Always insert in the same order as incoming list
            foreach (var row in incoming)
                Uow.SalesRoutes.Add(row);

            Uow.Commit();
        }

        public bool CheckZeroPrice(PrintInvoiceReq printInvoiceReq)
        {
            return Uow.SalesRoutes.CheckZeroPrice(printInvoiceReq);
        }
    }
}
