using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.EntityFrameworkCore;
using System.Transactions;

namespace KLS.Services
{
    public class SalesRouteDetailService : BaseService, ISalesRouteDetailService
    {
        private const string PendingStatus = "PENDING";
        private const string RestockedStatus = "RESTOCKED";
        private const string UntrackedType = "UNTRACKED";

        private readonly IItemService _itemService;
        private readonly IItemUnitService _itemUnitService;

        public SalesRouteDetailService(IUnitOfWork uow, IItemService itemService, IItemUnitService itemUnitService) : base(uow)
        {
            _itemService = itemService;
            _itemUnitService = itemUnitService;
        }

        public IEnumerable<SalesRouteDetail>? GetList(int salesRouteId)
        {
            var returnItems = Uow.SalesRouteDetails.Find(c => c.SalesRouteId == salesRouteId).ToList();

            return ReturnItems(returnItems);
        }

        public IEnumerable<SalesRouteDetail>? GetList(DateOnly shipDate, string? shipRoute)
        {
            var returnItems = (from s in Uow.SalesRoutes.GetAll()
                               join sd in Uow.SalesRouteDetails.GetAll() on s.SalesRouteId equals sd.SalesRouteId
                               where s.ShipDate == shipDate && s.ShipRoute == shipRoute
                               select sd).ToList();

            return ReturnItems(returnItems);
        }

        public IEnumerable<SalesRouteDetail>? GetPendingUntracked()
        {
            var returnItems = (from s in Uow.SalesRoutes.GetAll()
                               join sd in Uow.SalesRouteDetails.GetAll() on s.SalesRouteId equals sd.SalesRouteId
                               where sd.ReturnType == UntrackedType
                                     && sd.ResolutionStatus == PendingStatus
                               orderby s.ShipDate descending, s.ShipRoute, sd.CreatedAt descending, sd.RouteDetailId descending
                               select new SalesRouteDetail
                               {
                                   RouteDetailId = sd.RouteDetailId,
                                   SalesRouteId = sd.SalesRouteId,
                                   ItemId = sd.ItemId,
                                   ItemUnitId = sd.ItemUnitId,
                                   Unit = sd.Unit,
                                   Qty = sd.Qty,
                                   FactorToBase = sd.FactorToBase,
                                   BaseQty = sd.BaseQty,
                                   IsMatch = sd.IsMatch,
                                   Fault = sd.Fault,
                                   Notes = sd.Notes,
                                   ReturnType = sd.ReturnType,
                                   ResolutionStatus = sd.ResolutionStatus,
                                   ResolvedAt = sd.ResolvedAt,
                                   ResolvedBy = sd.ResolvedBy,
                                   InventoryAdjId = sd.InventoryAdjId,
                                   InventoryAdjDetailId = sd.InventoryAdjDetailId,
                                   CreditMemoSalesId = sd.CreditMemoSalesId,
                                   CreatedAt = sd.CreatedAt,
                                   ShipDate = s.ShipDate,
                                   ShipRoute = s.ShipRoute
                               }).ToList();

            return ReturnItems(returnItems);
        }

        public SalesRouteDetail GetById(int detailId)
        {
            return Uow.SalesRouteDetails.GetById(detailId);
        }

        private IEnumerable<SalesRouteDetail>? ReturnItems(List<SalesRouteDetail>? returnItems)
        {
            var itemIds = returnItems?.Select(d => d.ItemId).Distinct().ToList();

            if (itemIds == null || itemIds.Count == 0)
                return [];

            var items = _itemService.GetByIds(itemIds);
            var itemMap = items.ToDictionary(x => x.ItemId);

            foreach (var returnItem in returnItems)
            {
                if (itemMap.TryGetValue(returnItem.ItemId, out var item))
                {
                    returnItem.ItemCode = item.ItemCode;
                    returnItem.ItemName = item.ItemName;
                    returnItem.PackSize = item.PackSize;
                }
            }

            return returnItems;
        }

        public SalesRouteDetail Create(SalesRouteDetail routeDetail)
        {
            var item = _itemService.GetBySearch(routeDetail.ItemCode);

            if (item == null)
                throw new KeyNotFoundException("Itemcode not found");

            if (item.Inactive)
                throw new KeyNotFoundException("This product already discontinue");

            routeDetail.ItemId = item.ItemId;
            routeDetail.ItemCode = item.ItemCode;
            routeDetail.ItemName = item.ItemName;
            routeDetail.PackSize = item.PackSize;

            var resolvedUnit = _itemUnitService.ResolveKeyboxUnit(item.ItemId, routeDetail.Unit);
            var itemPrice = _itemUnitService.GetItemPriceByCustomer(0, item.ItemId, resolvedUnit?.ItemUnitId);

            if (itemPrice != null)
            {
                routeDetail.Unit = itemPrice.DefaultUnit;
                routeDetail.ItemUnitId = itemPrice.ItemUnitId;
                routeDetail.FactorToBase = itemPrice.FactorToBase;
            }

            routeDetail.ReturnType = UntrackedType;
            routeDetail.ResolutionStatus = PendingStatus;
            routeDetail.BaseQty = ComputeBaseQty(routeDetail.Qty, routeDetail.FactorToBase);

            Uow.SalesRouteDetails.Add(routeDetail);
            Uow.Commit();

            return routeDetail;
        }

        public SalesRouteDetail Update(SalesRouteDetail routeDetail)
        {
            var detail = Uow.SalesRouteDetails.GetById(routeDetail.RouteDetailId);

            if (detail != null)
            {
                EnsurePendingEditable(detail);

                detail.Qty = routeDetail.Qty;
                detail.Unit = routeDetail.Unit;
                detail.Notes = routeDetail.Notes;
                detail.IsMatch = routeDetail.IsMatch;
                detail.Fault = routeDetail.Fault;
                detail.BaseQty = ComputeBaseQty(detail.Qty, detail.FactorToBase);

                Uow.SalesRouteDetails.Update(detail);
                Uow.Commit();
            }

            return detail;
        }

        public SalesRouteDetail UpdateUnit(SalesRouteDetail routeDetail)
        {
            var existing = GetById(routeDetail.RouteDetailId);

            if (existing != null)
            {
                EnsurePendingEditable(existing);

                var itemUnit = _itemUnitService.GetNextUnit(existing.ItemId, existing.Unit);

                if (itemUnit != null)
                {
                    existing.Unit = itemUnit.Unit;
                    existing.ItemUnitId = itemUnit.ItemUnitId;
                    existing.FactorToBase = itemUnit.FactorToBase;
                    existing.BaseQty = ComputeBaseQty(existing.Qty, existing.FactorToBase);
                }

                Uow.SalesRouteDetails.Update(existing);
                Uow.Commit();
            }

            return existing;
        }

        public SalesRouteDetail Restock(int detailId)
        {
            var detail = Uow.SalesRouteDetails.GetById(detailId);

            if (detail == null)
                throw new KeyNotFoundException("Return item not found.");

            EnsurePendingEditable(detail);

            var route = Uow.SalesRoutes.GetById(detail.SalesRouteId);
            var closingQty = Uow.InventoryAdjs.GetClosingQty(detail.ItemId)?.ClosingQty ?? 0;
            var restockQty = detail.BaseQty.GetValueOrDefault(0);

            if (restockQty <= 0)
                throw new InvalidOperationException("Return item must have a positive base quantity before restock.");

            var adjDate = route?.ShipDate ?? DateOnly.FromDateTime(DateTime.Today);
            var detailNote = BuildRestockDetailNote(route, detail);
            var headerNote = BuildRestockHeaderNote(route, detail);

            using var scope = new TransactionScope(TransactionScopeOption.Required, TransactionScopeAsyncFlowOption.Enabled);

            var tempSnapshot = Uow.TempInventoryAdjs.Find(c => c.EmpId == UserContext.EmpId)
                .ToList();

            if (tempSnapshot.Count > 0)
            {
                Uow.TempInventoryAdjs.Find(c => c.EmpId == UserContext.EmpId).ExecuteDelete();
            }

            Uow.TempInventoryAdjs.Add(new TempInventoryAdj
            {
                EmpId = UserContext.EmpId,
                AdjId = 0,
                ItemId = detail.ItemId,
                NewQty = closingQty + restockQty,
                QtyDiffer = 0,
                NewPrice = 0,
                Notes = detailNote,
                ChangeStatus = EnumHelper.ChangeStatus.I.ToString()
            });
            Uow.Commit();

            var adjId = Uow.InventoryAdjs.Save(new InventoryAdj
            {
                AdjDate = adjDate,
                AdjType = "Q",
                Notes = headerNote
            });

            var adjDetailId = Uow.InventoryAdjDetails.Find(c => c.AdjId == adjId && c.ItemId == detail.ItemId)
                .OrderByDescending(c => c.AdjDetailId)
                .Select(c => c.AdjDetailId)
                .FirstOrDefault();

            detail.ResolutionStatus = RestockedStatus;
            detail.ResolvedAt = DateTime.UtcNow;
            detail.ResolvedBy = UserContext.EmpId == 0 ? null : UserContext.EmpId;
            detail.InventoryAdjId = adjId;
            detail.InventoryAdjDetailId = adjDetailId == 0 ? null : adjDetailId;

            Uow.SalesRouteDetails.Update(detail);
            Uow.Commit();

            RestoreTempSnapshot(tempSnapshot);

            scope.Complete();

            return detail;
        }

        public void Delete(int detailId)
        {
            var existing = GetById(detailId);

            if (existing == null)
                return;

            EnsurePendingEditable(existing);

            Uow.SalesRouteDetails.RemoveById(detailId);
            Uow.Commit();
        }

        private static decimal ComputeBaseQty(decimal? qty, decimal? factorToBase)
        {
            var factor = factorToBase.GetValueOrDefault(1);

            if (factor == 0)
                factor = 1;

            return Utilities.Rounding(qty.GetValueOrDefault(0) / factor, 6) ?? 0;
        }

        private static void EnsurePendingEditable(SalesRouteDetail detail)
        {
            if (!string.Equals(detail.ResolutionStatus, PendingStatus, StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("Only pending return items can be modified.");

            if (detail.InventoryAdjId.HasValue || detail.InventoryAdjDetailId.HasValue || detail.CreditMemoSalesId.HasValue)
                throw new InvalidOperationException("Resolved return items cannot be modified.");
        }

        private void RestoreTempSnapshot(List<TempInventoryAdj> snapshot)
        {
            if (snapshot.Count == 0)
                return;

            var restoredRows = snapshot.Select(x => new TempInventoryAdj
            {
                EmpId = x.EmpId,
                AdjId = x.AdjId,
                ItemId = x.ItemId,
                NewQty = x.NewQty,
                QtyDiffer = x.QtyDiffer,
                NewPrice = x.NewPrice,
                Notes = x.Notes,
                ChangeStatus = x.ChangeStatus,
                AdjDetailId = x.AdjDetailId,
                Direction = x.Direction
            });

            Uow.TempInventoryAdjs.AddRange(restoredRows);
            Uow.Commit();
        }

        private static string BuildRestockHeaderNote(SalesRoute? route, SalesRouteDetail detail)
        {
            var routeName = string.IsNullOrWhiteSpace(route?.ShipRoute) ? "No Route" : route!.ShipRoute;
            var shipDate = route?.ShipDate.ToString("yyyy-MM-dd") ?? DateTime.Today.ToString("yyyy-MM-dd");
            var itemCode = string.IsNullOrWhiteSpace(detail.ItemCode) ? detail.ItemId.ToString() : detail.ItemCode;

            return $"Untrack Return Restock - {routeName} - {shipDate} - {itemCode}";
        }

        private static string BuildRestockDetailNote(SalesRoute? route, SalesRouteDetail detail)
        {
            var routeName = string.IsNullOrWhiteSpace(route?.ShipRoute) ? "No Route" : route!.ShipRoute;
            var shipDate = route?.ShipDate.ToString("yyyy-MM-dd") ?? DateTime.Today.ToString("yyyy-MM-dd");
            var itemCode = string.IsNullOrWhiteSpace(detail.ItemCode) ? detail.ItemId.ToString() : detail.ItemCode;

            return $"Driver Sheet return restock from {routeName} {shipDate} - {itemCode}";
        }
    }
}
