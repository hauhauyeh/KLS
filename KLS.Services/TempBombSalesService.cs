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
    public class TempBombSalesService : BaseService, ITempBombSalesService
    {
        private readonly IItemUnitService _itemUnitService;
        private readonly IItemService _itemService;

        public TempBombSalesService(IUnitOfWork uow, IItemUnitService itemUnitService, IItemService itemService) : base(uow)
        {
            _itemUnitService = itemUnitService;
            _itemService = itemService;
        }

        public IEnumerable<BombSalesItem> GetList(bool checkAgain)
        {
            return Uow.TempBombSales.GetList(checkAgain, null);
        }

        public TempBombSales GetById(int tempId)
        {
            return Uow.TempBombSales.GetById(tempId);
        }

        public BombSalesItem GetListById(int tempId)
        {
            return Uow.TempBombSales.GetList(false, tempId).AsEnumerable().FirstOrDefault()!;
        }

        public void Inject(BombSalesReq bombSalesReq)
        {
            Uow.TempBombSales.Inject(bombSalesReq);
        }

        public BombSalesItem Update(BombSalesItem bombItem)
        {
            var existing = GetById(bombItem.TempBombId);

            if (existing != null)
            {
                existing.ShipQty = bombItem.ShipQty;
                existing.BillQty = bombItem.BillQty;
                existing.UnitPrice = bombItem.UnitPrice;
                existing.Notes = bombItem.Notes;
                existing.IsUserOverWrite = bombItem.IsUserOverWrite;
                existing.IsChanged = true;

                if (bombItem.ShipQty != 0 || bombItem.BillQty != 0)
                {
                    if (bombItem.ShipQty != 0)
                        existing.OrdQty = bombItem.ShipQty;
                    if (bombItem.BillQty != 0)
                        existing.OrdQty = bombItem.BillQty;
                }

                if (bombItem.IsDefaultPrice)
                {
                    var itemPrice = _itemUnitService.GetItemPriceByCustomer(bombItem.PayeeId, existing.ItemId ?? 0, existing.ItemUnitId);
                    existing.UnitPrice = itemPrice.DefaultPrice;
                }

                Uow.TempBombSales.Update(existing);
                Uow.Commit();
            }

            return GetListById(existing.TempBombId);
        }

        public BombSalesItem UpdateUnit(BombSalesItem bombItem)
        {
            var existing = GetById(bombItem.TempBombId);

            if (existing != null)
            {
                var itemUnit = _itemUnitService.GetNextUnit(existing.ItemId ?? 0, existing.Unit);
                var itemPrice = _itemUnitService.GetItemPriceByCustomer(existing.PayeeId, existing.ItemId ?? 0, itemUnit.ItemUnitId);

                existing.Unit = itemUnit.Unit;
                existing.UnitPrice = itemPrice.DefaultPrice;
                existing.FactorToBase = itemUnit.FactorToBase;
                existing.IsChanged = true;

                Uow.TempBombSales.Update(existing);
                Uow.Commit();
            }

            return GetListById(existing.TempBombId);
        }

        public BombSalesItem UpdateCode(BombSalesItem bombItem)
        {
            var existing = GetById(bombItem.TempBombId);

            if (existing != null)
            {
                // Get Product by Code,description,barcode
                var item = _itemService.GetBySearch(bombItem.ItemCode);

                if (item == null)
                    throw new KeyNotFoundException("Product code not found");

                if (item.Inactive)
                    throw new KeyNotFoundException("This product already discontinue");

                var itemPrice = _itemUnitService.GetItemPriceByCustomer(existing.PayeeId, item.ItemId, null);

                existing.ItemId = item.ItemId;
                existing.ItemUnitId = itemPrice.ItemUnitId;
                existing.Unit = itemPrice.DefaultUnit;
                existing.UnitPrice = itemPrice.DefaultPrice;
                existing.FactorToBase = itemPrice.FactorToBase;
                existing.IsTaxable = itemPrice.IsTaxable;
                existing.IsChanged = true;

                Uow.TempBombSales.Update(existing);
                Uow.Commit();
            }

            return GetListById(existing.TempBombId);
        }

        public void SaveBomb()
        {
            Uow.TempBombSales.SaveBomb();
        }
    }
}
