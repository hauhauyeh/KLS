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

        public SalesRoute GetById(int salesRouteId)
        {
            return Uow.SalesRoutes.GetById(salesRouteId);
        }

        public SalesRoute Create(SalesRoute salesRoute)
        {
            var route = Uow.SalesRoutes.Find(c => c.ShipDate == salesRoute.ShipDate && c.ShipRoute == salesRoute.ShipRoute).ToList();

            if (route.Count > 0)
            {
                return route.FirstOrDefault();
            }
            else
            {
                salesRoute.PrintCount = 0;
                Uow.SalesRoutes.Add(salesRoute);
                Uow.Commit();

                return salesRoute;
            }
        }

        public void UpdateInvoice(SalesRoute salesRoute)
        {
            var existingRoute = GetById(salesRoute.SalesRouteId);

            if (existingRoute != null)
            {
                var salesRows = Uow.Sales.Find(s => s.ShipDate == existingRoute.ShipDate && s.ShipRoute == existingRoute.ShipRoute).ToList();

                foreach (var sales in salesRows)
                {
                    sales.TruckNumber = string.IsNullOrWhiteSpace(salesRoute.TruckNumber) ? null : salesRoute.TruckNumber.Trim();
                    sales.Deliverby = salesRoute.DriverId;
                    sales.UpdatedAt = DateTime.UtcNow;
                    Uow.Sales.Update(sales);
                }

                Uow.Commit();
                SyncByDate(existingRoute.ShipDate);

                existingRoute = GetById(salesRoute.SalesRouteId);

                if (existingRoute == null)
                    return;

                existingRoute.Loader = salesRoute.Loader;
                existingRoute.Checker = salesRoute.Checker;
                existingRoute.FuelCash = salesRoute.FuelCash;
                existingRoute.FuelCard = salesRoute.FuelCard;
                existingRoute.BeginMileage = salesRoute.BeginMileage;
                existingRoute.TruckIssue = salesRoute.TruckIssue;
                existingRoute.PrintCount = (existingRoute.PrintCount ?? 0) + 1;
                existingRoute.UpdatedAt = DateTime.UtcNow;

                Uow.SalesRoutes.Update(existingRoute);
                Uow.Commit();
            }
        }

        public void UpdateDriverSheet(SalesRoute salesRoute)
        {
            var existingRoute = GetById(salesRoute.SalesRouteId);

            if (existingRoute != null)
            {
                existingRoute.Officer = salesRoute.Officer;
                existingRoute.FuelReceipt = salesRoute.FuelReceipt;
                existingRoute.CashChangeBack = salesRoute.CashChangeBack;
                existingRoute.HandTruckBack = salesRoute.HandTruckBack;
                existingRoute.FullTank = salesRoute.FullTank;
                existingRoute.SweepTruck = salesRoute.SweepTruck;
                existingRoute.SweepCab = salesRoute.SweepCab;
                existingRoute.EndMileage = salesRoute.EndMileage;
                existingRoute.InvoiceCount = salesRoute.InvoiceCount;
                existingRoute.CheckCount = salesRoute.CheckCount;
                existingRoute.CashCount = salesRoute.CashCount;
                existingRoute.Notes = salesRoute.Notes;
                existingRoute.KeyReturned = salesRoute.KeyReturned;
                existingRoute.UpdatedAt = DateTime.UtcNow;

                Uow.SalesRoutes.Update(existingRoute);
                Uow.Commit();
            }
        }

        public SalesRoute? GetByDateRoute(DateOnly? shipDate, string? shipRoute)
        {
            return Uow.SalesRoutes.Find(c => c.ShipDate == shipDate && c.ShipRoute == shipRoute).FirstOrDefault();
        }

        public IEnumerable<AssignTruck>? GetAssignTrucks(DateOnly shipDate)
        {
            var trucks = _truckService.GetActive().ToList();

            var assignRoutes = Uow.SalesRoutes.Find(c => c.ShipDate == shipDate).OrderBy(c => c.SalesRouteId).ToList();

            var routeAssignments = Uow.Sales.Find(c => c.ShipDate == shipDate && c.ShipRoute != null)
                .AsEnumerable()
                .Where(c => !string.IsNullOrWhiteSpace(c.ShipRoute))
                .GroupBy(c => c.ShipRoute!.Trim())
                .ToDictionary(
                    g => g.Key,
                    g => new
                    {
                        TruckNumber = g.Select(x => string.IsNullOrWhiteSpace(x.TruckNumber) ? null : x.TruckNumber!.Trim()).FirstOrDefault(x => !string.IsNullOrEmpty(x)),
                        DriverId = g.Select(x => x.Deliverby).FirstOrDefault(x => x.HasValue)
                    });

            foreach (var route in assignRoutes)
            {
                if (routeAssignments.TryGetValue((route.ShipRoute ?? string.Empty).Trim(), out var assignment))
                {
                    route.TruckNumber = assignment.TruckNumber;
                    route.Driver = assignment.DriverId.HasValue
                        ? Uow.Payees.GetById(assignment.DriverId.Value)?.PayeeName
                        : null;
                }
            }

            // Group only assigned routes by a non-empty truck number. Unassigned routes
            // are still valid rows in SalesRoute, but they cannot be used as dictionary
            // keys and should simply remain outside the truck lookup.
            var routeLookup = assignRoutes?
                .Where(r => !string.IsNullOrWhiteSpace(r.TruckNumber))
                .GroupBy(r => r.TruckNumber!.Trim())
                .ToDictionary(
                    g => g.Key,
                    g => g
                        .OrderBy(r => r.TruckRouteOrder ?? int.MaxValue)
                        .ThenBy(r => r.SalesRouteId)
                        .ToList());

            var assignTrucks = trucks
           .Select(truck =>
           {
               routeLookup.TryGetValue(truck.TruckNumber, out var routes);

               return new AssignTruck
               {
                   TruckNumber = truck.TruckNumber,
                   Routes = routes,
                   DriverId = routes?.Select(r =>
                   {
                       if (routeAssignments.TryGetValue((r.ShipRoute ?? string.Empty).Trim(), out var assignment))
                           return assignment.DriverId;
                       return null;
                   }).FirstOrDefault(x => x.HasValue),
                   DriverName = routes?.FirstOrDefault()?.Driver
               };
           })

           // Preserve explicit assign-truck sequence when it exists, then fall back.
           .OrderBy(at => at.Routes?.FirstOrDefault()?.TruckRouteOrder ?? int.MaxValue)
           .ThenBy(at => at.Routes?.FirstOrDefault()?.SalesRouteId ?? int.MaxValue)
           .ThenBy(at => at.TruckNumber)
           .ToList();

            return assignTrucks;
        }

        public void SaveAssignTrucks(List<AssignTruck> assignTrucks)
        {
            if (assignTrucks == null || assignTrucks.Count == 0)
                return;

            var incoming = new List<(DateOnly ShipDate, string ShipRoute, string? TruckNumber, int? Deliverby, int TruckRouteOrder)>();
            var truckRouteOrder = 0;

            foreach (var truck in assignTrucks.Where(t => t.Routes != null && t.Routes.Count > 0))
            {
                foreach (var route in truck.Routes!)
                {
                    var shipRoute = (route.ShipRoute ?? "").Trim();
                    if (string.IsNullOrWhiteSpace(shipRoute))
                        continue;

                    truckRouteOrder += 1;
                    incoming.Add((
                        route.ShipDate,
                        shipRoute,
                        string.IsNullOrWhiteSpace(truck.TruckNumber) ? null : truck.TruckNumber.Trim(),
                        truck.DriverId,
                        truckRouteOrder
                    ));
                }
            }

            if (incoming.Count == 0)
                return;

            var shipDate = incoming[0].ShipDate;

            var routeAssignments = incoming.ToDictionary(
                x => x.ShipRoute,
                x => new
                {
                    TruckNumber = x.TruckNumber,
                    Deliverby = x.Deliverby,
                    TruckRouteOrder = x.TruckRouteOrder
                },
                StringComparer.OrdinalIgnoreCase);

            var salesRows = Uow.Sales.Find(s => s.ShipDate == shipDate && s.ShipRoute != null).ToList();

            foreach (var sales in salesRows)
            {
                var shipRoute = sales.ShipRoute?.Trim();

                if (string.IsNullOrWhiteSpace(shipRoute))
                    continue;

                if (routeAssignments.TryGetValue(shipRoute, out var assignment))
                {
                    sales.TruckNumber = assignment.TruckNumber;
                    sales.Deliverby = assignment.Deliverby;
                    sales.UpdatedAt = DateTime.UtcNow;
                    Uow.Sales.Update(sales);
                }
            }

            Uow.Commit();
            SyncByDate(shipDate);

            var salesRoutes = Uow.SalesRoutes.Find(r => r.ShipDate == shipDate).ToList();
            foreach (var route in salesRoutes)
            {
                route.TruckRouteOrder = null;

                var shipRoute = route.ShipRoute?.Trim();
                if (!string.IsNullOrWhiteSpace(shipRoute) &&
                    routeAssignments.TryGetValue(shipRoute, out var assignment) &&
                    !string.IsNullOrWhiteSpace(assignment.TruckNumber))
                {
                    route.TruckRouteOrder = assignment.TruckRouteOrder;
                }

                Uow.SalesRoutes.Update(route);
            }

            Uow.Commit();
        }

        public void SyncByDate(DateOnly shipDate)
        {
            Uow.SalesRoutes.SyncByDate(shipDate);
        }

        public bool CheckZeroPrice(PrintInvoiceReq printInvoiceReq)
        {
            return Uow.SalesRoutes.CheckZeroPrice(printInvoiceReq);
        }
    }
}
