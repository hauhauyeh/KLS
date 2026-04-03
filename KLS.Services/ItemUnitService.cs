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
    public class ItemUnitService : BaseService, IItemUnitService
    {
        public ItemUnitService(IUnitOfWork uow) : base(uow)
        {
        }

        public List<ItemUnit> GetByItemId(int itemId)
        {
            return Uow.ItemUnits.Find(c => c.ItemId == itemId && c.Inactive == false).OrderBy(i => i.ItemUnitId).ToList();
        }

        public ItemUnit GetBaseUnit(int itemId)
        {
            return Uow.ItemUnits.Find(c => c.ItemId == itemId && c.IsBaseUnit).FirstOrDefault()!;
        }

        public ItemUnit GetSalesUnit(int itemId)
        {
            return Uow.ItemUnits.Find(c => c.ItemId == itemId && c.IsDefaultSalesUnit).FirstOrDefault()!;
        }

        public ItemUnit GetNextUnit(int itemId, string unit)
        {
            var units = GetByItemId(itemId);

            var idx = units.FindIndex(x => x.Unit == unit);
            if (idx < 0) return units[0];           // default

            return units[(idx + 1) % units.Count];  // cycle
        }

        public ItemPrice GetItemPriceByCustomer(int payeeId, int itemId, int? itemUnitId)
        {
            return Uow.ItemUnits.GetItemPriceByCustomer(payeeId, itemId, itemUnitId);
        }

        public ItemUnit? ResolveKeyboxUnit(int itemId, string? keyboxUnit)
        {
            if (string.IsNullOrWhiteSpace(keyboxUnit))
                return null;

            var units = GetByItemId(itemId); // already excludes inactive
            if (units == null || units.Count == 0)
                return null;

            var baseUnit = units.FirstOrDefault(u => u.IsBaseUnit);

            if (string.IsNullOrWhiteSpace(keyboxUnit))
                return baseUnit ?? units.First();

            keyboxUnit = keyboxUnit.Trim().ToLower();

            // w = base unit
            if (keyboxUnit == "w")
                return baseUnit ?? units.First();

            // r = first non-base unit
            if (keyboxUnit == "r")
            {
                var retailUnit = units.FirstOrDefault(u => !u.IsBaseUnit);
                return retailUnit ?? baseUnit ?? units.First();
            }

            // future-proof: allow actual unit match (kg, box, etc.)
            var matched = units.FirstOrDefault(u => u.Unit.ToLower() == keyboxUnit);
            if (matched != null)
                return matched;

            // fallback safe
            return baseUnit ?? units.First();
        }

        public IEnumerable<ItemUnitListRow> GetUnitViewList(string itemIds)
        {
            return Uow.ItemUnits.GetUnitViewList(itemIds);
        }

        public void UpdateUnit(ItemUnitUpdateReq req)
        {
            var unit = Uow.ItemUnits.GetById(req.ItemUnitId);
            if (unit == null) return;

            // Base unit FactorToBase must remain 1
            if (unit.IsBaseUnit && req.FactorToBase.HasValue && req.FactorToBase.Value != 1)
                throw new InvalidOperationException("Cannot change FactorToBase on base unit.");

            if (req.Unit != null)
            {
                var trimmedUnit = req.Unit.Trim();
                if (!string.IsNullOrEmpty(trimmedUnit))
                    unit.Unit = trimmedUnit;
            }

            if (req.P1.HasValue)
                unit.P1 = req.P1.Value;

            if (req.Barcode != null)
            {
                var trimmed = req.Barcode.Trim();
                if (!string.IsNullOrEmpty(trimmed))
                {
                    var duplicate = Uow.ItemUnits.Find(u => u.Barcode == trimmed && u.ItemUnitId != req.ItemUnitId).Any();
                    if (duplicate)
                        throw new InvalidOperationException("Barcode already exists on another unit.");
                }
                unit.Barcode = trimmed;
            }

            if (req.FactorToBase.HasValue && !unit.IsBaseUnit)
                unit.FactorToBase = req.FactorToBase.Value;

            if (req.PricePercentToBase.HasValue && !unit.IsBaseUnit)
                unit.PricePercentToBase = req.PricePercentToBase.Value;

            if (req.IsDefaultSalesUnit.HasValue)
            {
                if (req.IsDefaultSalesUnit.Value)
                {
                    // Un-toggle all other units for this item
                    var siblings = Uow.ItemUnits.Find(u => u.ItemId == unit.ItemId && u.ItemUnitId != unit.ItemUnitId && u.IsDefaultSalesUnit);

                    foreach (var s in siblings)
                    {
                        s.IsDefaultSalesUnit = false;
                        Uow.ItemUnits.Update(s);
                    }
                }
                unit.IsDefaultSalesUnit = req.IsDefaultSalesUnit.Value;
            }

            if (req.Inactive.HasValue)
                unit.Inactive = req.Inactive.Value;

            Uow.ItemUnits.Update(unit);
            Uow.Commit();
        }

        public ItemUnit CreateUnit(int itemId)
        {
            var baseUnit = GetBaseUnit(itemId);
            var baseP1 = baseUnit?.P1 ?? 0;

            // Get default markup from SystemSetting
            var defaultPercent = Uow.SystemSettings
                .Find(s => s.SettingKey == "ITEM_DEFAULT_RETAILPROFIT")
                .Select(s => s.SettingValue)
                .FirstOrDefault();

            decimal markup = 0.4m;

            if (decimal.TryParse(defaultPercent, out var parsed))
                markup = parsed;

            var existingCount = Uow.ItemUnits.Find(u => u.ItemId == itemId).Count();
            decimal factorToBase = 1;
            decimal p1 = CalcRetailP1(baseP1, factorToBase, markup);

            var unit = new ItemUnit
            {
                ItemId = itemId,
                Unit = "unit" + (existingCount + 1),
                FactorToBase = factorToBase,
                PricePercentToBase = markup,
                P1 = p1,
                IsBaseUnit = false,
                IsDefaultSalesUnit = false,
                Inactive = false
            };

            Uow.ItemUnits.Add(unit);
            Uow.Commit();

            return unit;
        }

        private static decimal CalcRetailP1(decimal baseP1, decimal factorToBase, decimal markup)
        {
            if (factorToBase <= 0) factorToBase = 1;
            if (markup >= 1) return 0; // 100% markup is invalid
            return Math.Round((baseP1 / (1 - markup)) / factorToBase, 2);
        }

        public void DeleteUnit(int itemUnitId)
        {
            //var unit = Uow.ItemUnits.GetById(itemUnitId);

            //if (unit == null) return;

            //if (unit.IsBaseUnit)
            //    throw new InvalidOperationException("Cannot delete base unit.");

            Uow.ItemUnits.Delete(itemUnitId);
        }
    }
}
