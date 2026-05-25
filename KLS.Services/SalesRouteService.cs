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
                existingRoute.TruckNumber = NormalizeTruckNumber(salesRoute.TruckNumber);
                if (salesRoute.DriverId.HasValue)
                {
                    existingRoute.DriverId = salesRoute.DriverId;
                    existingRoute.Driver = ResolveDriverName(salesRoute.DriverId, salesRoute.Driver);
                }
                existingRoute.UpdatedAt = DateTime.UtcNow;
                var salesRows = Uow.Sales.Find(s => s.ShipDate == existingRoute.ShipDate && s.ShipRoute == existingRoute.ShipRoute).ToList();

                foreach (var sales in salesRows)
                {
                    sales.TruckNumber = existingRoute.TruckNumber;
                    sales.Deliverby = existingRoute.DriverId;
                    sales.UpdatedAt = DateTime.UtcNow;
                    Uow.Sales.Update(sales);
                }

                // Loader: resolve from LoaderId when set, mirroring DriverId pattern.
                // LoaderId is the source of truth; Loader text is a denormalized
                // PayeeName cache for read-side speed (reports + invoice PDF).
                existingRoute.LoaderId = salesRoute.LoaderId;
                existingRoute.Loader = ResolveLoaderName(salesRoute.LoaderId, salesRoute.Loader);

                // Checker: same FK pattern (CheckerId added 2026-05-25).
                existingRoute.CheckerId = salesRoute.CheckerId;
                existingRoute.Checker = ResolveCheckerName(salesRoute.CheckerId, salesRoute.Checker);
                existingRoute.FuelCash = salesRoute.FuelCash;
                existingRoute.FuelCard = salesRoute.FuelCard;
                existingRoute.BeginMileage = salesRoute.BeginMileage;
                existingRoute.TruckIssue = salesRoute.TruckIssue;
                // PrintCount increment moved to DocumentService.Invoice (after merged.SaveAs)
                // so Save Only no longer counts as a print and failed PDF gen doesn't either.

                Uow.SalesRoutes.Update(existingRoute);
                Uow.Commit();
            }
        }

        public void UpdateDriverSheet(SalesRoute salesRoute)
        {
            var existingRoute = GetById(salesRoute.SalesRouteId);

            if (existingRoute != null)
            {
                // Officer: same FK pattern as Driver/Loader/Checker.
                // OfficerId is the source of truth; Officer text is the
                // denormalized PayeeName cache for reports + driver sheet PDF.
                existingRoute.OfficerId = salesRoute.OfficerId;
                existingRoute.Officer = ResolveOfficerName(salesRoute.OfficerId, salesRoute.Officer);
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
            var activeTrucks = _truckService.GetActive()
                .Select(t => NormalizeTruckNumber(t.TruckNumber))
                .Where(t => !string.IsNullOrWhiteSpace(t))
                .ToList();

            var assignRoutes = Uow.SalesRoutes.Find(c => c.ShipDate == shipDate)
                .OrderBy(c => c.TruckRouteOrder ?? int.MaxValue)
                .ThenBy(c => c.SalesRouteId)
                .ToList();

            var driverNames = assignRoutes
                .Select(r => r.Driver?.Trim())
                .Where(n => !string.IsNullOrWhiteSpace(n))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();

            var driverLookup = Uow.Payees.GetAll()
                .Where(p => driverNames.Contains(p.PayeeName!))
                .ToList()
                .GroupBy(p => p.PayeeName ?? string.Empty, StringComparer.OrdinalIgnoreCase)
                .Where(g => g.Select(p => p.PayeeId).Distinct().Count() == 1)
                .ToDictionary(g => g.Key, g => g.First().PayeeId, StringComparer.OrdinalIgnoreCase);

            var assignedTrucks = assignRoutes
                .Where(r => !string.IsNullOrWhiteSpace(r.TruckNumber))
                .GroupBy(r => NormalizeTruckNumber(r.TruckNumber)!, StringComparer.OrdinalIgnoreCase)
                .OrderBy(g => g.Min(r => r.TruckRouteOrder ?? int.MaxValue))
                .ThenBy(g => g.Min(r => r.SalesRouteId))
                .Select(g =>
                {
                    var routes = g
                        .OrderBy(r => r.TruckRouteOrder ?? int.MaxValue)
                        .ThenBy(r => r.SalesRouteId)
                        .ToList();

                    var driverId = routes.Select(r => r.DriverId).FirstOrDefault(id => id.HasValue);
                    var driverName = routes.Select(r => r.Driver?.Trim()).FirstOrDefault(n => !string.IsNullOrWhiteSpace(n));
                    return new AssignTruck
                    {
                        TruckNumber = g.Key,
                        Routes = routes,
                        DriverName = driverName,
                        DriverId = driverId ?? ResolveDriverId(driverLookup, driverName)
                    };
                })
                .ToList();

            var assignedTruckNumbers = new HashSet<string>(
                assignedTrucks
                    .Select(t => NormalizeTruckNumber(t.TruckNumber))
                    .Where(t => !string.IsNullOrWhiteSpace(t))!,
                StringComparer.OrdinalIgnoreCase);

            foreach (var truckNumber in activeTrucks.Where(t => !assignedTruckNumbers.Contains(t!)))
            {
                assignedTrucks.Add(new AssignTruck
                {
                    TruckNumber = truckNumber
                });
            }

            return assignedTrucks;
        }

        public void SaveAssignTrucks(List<AssignTruck> assignTrucks)
        {
            if (assignTrucks == null || assignTrucks.Count == 0)
                return;

            var incoming = new List<(DateOnly ShipDate, string ShipRoute, string? TruckNumber, int? Deliverby, string? DriverName, int TruckRouteOrder)>();
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
                        NormalizeTruckNumber(truck.TruckNumber),
                        truck.DriverId,
                        ResolveDriverName(truck.DriverId, truck.DriverName),
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
                    DriverName = x.DriverName,
                    TruckRouteOrder = x.TruckRouteOrder
                },
                StringComparer.OrdinalIgnoreCase);

            var salesRoutes = Uow.SalesRoutes.Find(r => r.ShipDate == shipDate).ToList();
            var existingRouteLookup = salesRoutes
                .Where(r => !string.IsNullOrWhiteSpace(r.ShipRoute))
                .GroupBy(r => r.ShipRoute.Trim(), StringComparer.OrdinalIgnoreCase)
                .ToDictionary(g => g.Key, g => g.First(), StringComparer.OrdinalIgnoreCase);

            foreach (var assignment in incoming)
            {
                if (existingRouteLookup.ContainsKey(assignment.ShipRoute))
                    continue;

                var newRoute = new SalesRoute
                {
                    ShipDate = assignment.ShipDate,
                    ShipRoute = assignment.ShipRoute,
                    PrintCount = 0
                };

                Uow.SalesRoutes.Add(newRoute);
                salesRoutes.Add(newRoute);
                existingRouteLookup[assignment.ShipRoute] = newRoute;
            }

            Uow.Commit();

            salesRoutes = Uow.SalesRoutes.Find(r => r.ShipDate == shipDate).ToList();
            foreach (var route in salesRoutes)
            {
                var shipRoute = route.ShipRoute?.Trim();
                if (!string.IsNullOrWhiteSpace(shipRoute) &&
                    routeAssignments.TryGetValue(shipRoute, out var assignment))
                {
                    route.TruckNumber = assignment.TruckNumber;
                    route.DriverId = assignment.Deliverby;
                    route.Driver = assignment.DriverName;
                    route.TruckRouteOrder = assignment.TruckRouteOrder;
                }
                else
                {
                    route.TruckNumber = null;
                    route.DriverId = null;
                    route.Driver = null;
                    route.TruckRouteOrder = null;
                }

                route.UpdatedAt = DateTime.UtcNow;
                Uow.SalesRoutes.Update(route);
            }

            Uow.Commit();

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
                }
                else
                {
                    sales.TruckNumber = null;
                    sales.Deliverby = null;
                }

                sales.UpdatedAt = DateTime.UtcNow;
                Uow.Sales.Update(sales);
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

        private static string? NormalizeTruckNumber(string? truckNumber)
        {
            return string.IsNullOrWhiteSpace(truckNumber) ? null : truckNumber.Trim();
        }

        private string? ResolveDriverName(int? driverId, string? fallbackDriverName)
        {
            if (driverId.HasValue)
                return Uow.Payees.GetById(driverId.Value)?.PayeeName;

            return string.IsNullOrWhiteSpace(fallbackDriverName) ? null : fallbackDriverName.Trim();
        }

        // Mirrors ResolveDriverName. LoaderId added 2026-05-25; same source-of-truth
        // pattern (FK is canonical, text column is a denormalized PayeeName cache).
        private string? ResolveLoaderName(int? loaderId, string? fallbackLoaderName)
        {
            if (loaderId.HasValue)
                return Uow.Payees.GetById(loaderId.Value)?.PayeeName;

            return string.IsNullOrWhiteSpace(fallbackLoaderName) ? null : fallbackLoaderName.Trim();
        }

        // CheckerId and OfficerId added 2026-05-25 alongside Loader to finish
        // the FK upgrade across all four crew-role fields on SalesRoute.
        private string? ResolveCheckerName(int? checkerId, string? fallbackCheckerName)
        {
            if (checkerId.HasValue)
                return Uow.Payees.GetById(checkerId.Value)?.PayeeName;

            return string.IsNullOrWhiteSpace(fallbackCheckerName) ? null : fallbackCheckerName.Trim();
        }

        private string? ResolveOfficerName(int? officerId, string? fallbackOfficerName)
        {
            if (officerId.HasValue)
                return Uow.Payees.GetById(officerId.Value)?.PayeeName;

            return string.IsNullOrWhiteSpace(fallbackOfficerName) ? null : fallbackOfficerName.Trim();
        }

        private static int? ResolveDriverId(Dictionary<string, int> driverLookup, string? driverName)
        {
            if (string.IsNullOrWhiteSpace(driverName))
                return null;

            return driverLookup.TryGetValue(driverName.Trim(), out var payeeId) ? payeeId : null;
        }
    }
}
