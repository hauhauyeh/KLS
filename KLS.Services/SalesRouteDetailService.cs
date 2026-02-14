using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Omu.ValueInjecter;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class SalesRouteDetailService : BaseService, ISalesRouteDetailService
    {
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

        public SalesRouteDetail GetById(int detailId)
        {
            return Uow.SalesRouteDetails.GetById(detailId);
        }

        private IEnumerable<SalesRouteDetail>? ReturnItems(List<SalesRouteDetail>? returnItems)
        {
            // 1) collect unique item ids
            var itemIds = returnItems?.Select(d => d.ItemId).Distinct().ToList();

            if (itemIds.Count == 0)
                return [];

            // 2) fetch all items in one call (add this method in item service/repo)
            var items = _itemService.GetByIds(itemIds); // returns List<Item> (or IEnumerable<Item>)
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
            // Get Product by Code,description,barcode
            var item = _itemService.GetBySearch(routeDetail.ItemCode);

            if (item == null)
                throw new KeyNotFoundException("Itemcode not found");

            if (item.Inactive)
                throw new KeyNotFoundException("This product already discontinue");

            routeDetail.ItemId = item.ItemId;
            routeDetail.ItemCode = item.ItemCode;
            routeDetail.ItemName = item.ItemName;
            routeDetail.PackSize = item.PackSize;

            var itemPrice = _itemUnitService.GetItemPriceByCustomer(0, item.ItemId, null);

            if (itemPrice != null)
            {
                routeDetail.Unit = itemPrice.DefaultUnit;
                routeDetail.ItemUnitId = itemPrice.ItemUnitId;
            }

            Uow.SalesRouteDetails.Add(routeDetail);
            Uow.Commit();

            return routeDetail;
        }

        public SalesRouteDetail Update(SalesRouteDetail routeDetail)
        {
            var detail = Uow.SalesRouteDetails.GetById(routeDetail.RouteDetailId);

            if (detail != null)
            {
                detail.Qty = routeDetail.Qty;
                detail.Unit = routeDetail.Unit;
                detail.Notes = routeDetail.Notes;
                detail.IsMatch = routeDetail.IsMatch;
                detail.Fault = routeDetail.Fault;

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
                var itemUnit = _itemUnitService.GetNextUnit(existing.ItemId, existing.Unit);

                if (itemUnit != null)
                {
                    existing.Unit = itemUnit.Unit;
                    existing.ItemUnitId = itemUnit.ItemUnitId;
                }

                Uow.SalesRouteDetails.Update(existing);
                Uow.Commit();
            }

            return existing;
        }

        public void Delete(int detailId)
        {
            Uow.SalesRouteDetails.RemoveById(detailId);
            Uow.Commit();
        }
    }
}
