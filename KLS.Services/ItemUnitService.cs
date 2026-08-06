using KLS.Contract.Dtos.Item;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using KLS.Services.Items;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class ItemUnitService : BaseService, IItemUnitService
    {
        private readonly ISystemSettingService _systemSettingService;

        public ItemUnitService(IUnitOfWork uow, ISystemSettingService systemSettingService) : base(uow)
        {
            _systemSettingService = systemSettingService;
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

        public ItemUnitMutationResult UpdateUnit(ItemUnitUpdateReq req)
        {
            var unit = Uow.ItemUnits.GetById(req.ItemUnitId);
            if (unit == null) return new ItemUnitMutationResult();

            // Immutability (master plan §5.1/§5.2, "saved => immutable"): a saved unit's ratio is frozen.
            // FactorToBase cannot change on an existing unit. (MultipleToBase is immutable-by-omission --
            // it is not on this request, so no update path can change it.) To correct a ratio, inactivate
            // this unit and add a new one. Subsumes the old "base unit FactorToBase must stay 1" rule.
            // Reject only an ACTUAL change -- the edit form may resend the unchanged ratio when saving
            // name/price/barcode, which is a harmless no-op.
            if (req.FactorToBase.HasValue && req.FactorToBase.Value != unit.FactorToBase)
                throw new InvalidOperationException(
                    "Cannot change the conversion factor on a saved unit. Inactivate this unit and add a new one instead.");

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

            // FactorToBase intentionally NOT assigned here -- it is immutable on a saved unit (guarded above).

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

            var setPacking = ItemSetPackingRecomputer.Apply(Uow, unit.ItemId);
            return new ItemUnitMutationResult
            {
                ItemId = unit.ItemId,
                SetPacking = setPacking
            };
        }

        // Create a non-base unit with its ratio set up-front (draft-row add flow). The old CreateUnit(itemId)
        // made an auto-named 1:1 unit that immutability then froze into junk ("unit2"). Now the caller supplies
        // name + ratio, and we validate it BEFORE persisting — the ratio can never be edited later.
        public ItemUnitMutationResult CreateUnit(CreateItemUnitReq req)
        {
            var itemId = req.ItemId;

            var name = (req.Unit ?? string.Empty).Trim();
            if (string.IsNullOrEmpty(name))
                throw new InvalidOperationException("Unit name is required.");

            // Normalize the ratio. FactorToBase = denominator, MultipleToBase = numerator; one side must be 1.
            var factorToBase = req.FactorToBase < 1 ? 1 : req.FactorToBase;
            var multipleToBase = req.MultipleToBase < 1 ? 1 : req.MultipleToBase;

            // Matches CK_ItemUnit_Ratio_OneSideOne — no odd fractions like 3/2 in v1.
            if (multipleToBase != 1 && factorToBase != 1)
                throw new InvalidOperationException("A unit ratio must be a whole ×N or ÷N of the base (one side must be 1).");

            // A non-base unit needs a real ratio (N >= 2). A 1/1 non-base unit is the junk we no longer allow.
            if (multipleToBase == 1 && factorToBase == 1)
                throw new InvalidOperationException("Enter a unit ratio of 2 or more (e.g. ×6 or ÷12).");

            // Friendly duplicate check (the filtered unique index UX_ItemUnit_Ratio also enforces this at the DB).
            var dup = Uow.ItemUnits
                .Find(u => u.ItemId == itemId && !u.Inactive
                        && u.MultipleToBase == multipleToBase && u.FactorToBase == factorToBase)
                .Any();
            if (dup)
                throw new InvalidOperationException("An active unit with this ratio already exists on this item. Inactivate it first, or use a different ratio.");

            var baseUnit = GetBaseUnit(itemId);
            var baseP1 = baseUnit?.P1 ?? 0;

            // Markup: caller value if given, else the ITEM_DEFAULT_RETAILPROFIT setting (fallback 0.40).
            decimal markup = 0.4m;
            if (req.PricePercentToBase.HasValue)
            {
                markup = req.PricePercentToBase.Value;
            }
            else
            {
                var defaultPercent = Uow.SystemSettings
                    .Find(s => s.SettingKey == "ITEM_DEFAULT_RETAILPROFIT")
                    .Select(s => s.SettingValue)
                    .FirstOrDefault();
                if (decimal.TryParse(defaultPercent, out var parsed))
                    markup = parsed;
            }

            // Default P1 from base + markup unless the caller supplied one.
            var p1 = req.P1 ?? CalcRetailP1(baseP1, factorToBase, multipleToBase, markup, _systemSettingService.GetPriceDecimals());

            var unit = new ItemUnit
            {
                ItemId = itemId,
                Unit = name,
                FactorToBase = factorToBase,
                MultipleToBase = multipleToBase,
                PricePercentToBase = markup,
                P1 = p1,
                Barcode = string.IsNullOrWhiteSpace(req.Barcode) ? null : req.Barcode.Trim(),
                IsBaseUnit = false,
                IsDefaultSalesUnit = false,
                Inactive = false
            };

            Uow.ItemUnits.Add(unit);
            Uow.Commit();

            var setPacking = ItemSetPackingRecomputer.Apply(Uow, itemId);
            return new ItemUnitMutationResult
            {
                ItemId = itemId,
                SetPacking = setPacking,
                Unit = unit
            };
        }

        // Retail P1 from the base P1, the unit's effective size (multiple/factor), and markup.
        // BaseQty = Qty * multiple / factor, so a unit's price scales by multiple/factor vs the base.
        private static decimal CalcRetailP1(decimal baseP1, decimal factorToBase, decimal multipleToBase, decimal markup, int priceDecimals = 2)
        {
            if (factorToBase <= 0) factorToBase = 1;
            if (multipleToBase <= 0) multipleToBase = 1;
            if (markup >= 1) return 0; // 100% markup is invalid
            // 4dp Section B Phase-2 (Slice 5): round to the active unit-price precision (2 or 4) instead of literal 2.
            return Math.Round((baseP1 / (1 - markup)) * multipleToBase / factorToBase, priceDecimals);
        }

        public ItemUnitMutationResult DeleteUnit(int itemUnitId)
        {
            // Capture ItemId before delete so we can recompute SetPacking after.
            var existing = Uow.ItemUnits.GetById(itemUnitId);
            if (existing == null) return new ItemUnitMutationResult();

            // Delete guard (A.5): the base unit is never deletable.
            if (existing.IsBaseUnit)
                throw new InvalidOperationException("Cannot delete the base unit.");

            // Delete only UNUSED units. A used unit (referenced in sales, quotes, purchases, routes, cart, or any
            // Temp* draft — see Fn_ItemUnit_IsUsed / the 13 ItemUnitId tables) must be INACTIVATED instead:
            // deleting it would orphan its history (those tables have no FK to ItemUnit).
            if (Uow.ItemUnits.IsUsed(itemUnitId))
                throw new InvalidOperationException(
                    "This unit is in use (sales, quotes, purchases, or open drafts) and cannot be deleted. Inactivate it instead.");

            var itemId = existing.ItemId;

            Uow.ItemUnits.Delete(itemUnitId);

            if (itemId == 0) return new ItemUnitMutationResult();

            var setPacking = ItemSetPackingRecomputer.Apply(Uow, itemId);
            return new ItemUnitMutationResult
            {
                ItemId = itemId,
                SetPacking = setPacking
            };
        }
    }
}
