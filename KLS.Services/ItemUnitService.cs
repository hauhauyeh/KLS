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
    }
}
