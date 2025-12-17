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
            return Uow.ItemUnits.Find(c => c.ItemId == itemId).OrderBy(i => i.ItemUnitId).ToList();
        }

        public ItemUnit GetBaseUnit(int itemId)
        {
            return Uow.ItemUnits.Find(c => c.ItemId == itemId && c.IsBaseUnit).FirstOrDefault()!;
        }

        public ItemUnit GetNextUnit(int itemId, string unit)
        {
            var units = GetByItemId(itemId);

            var idx = units.FindIndex(x => x.Unit == unit);
            if (idx < 0) return units[0];           // default

            return units[(idx + 1) % units.Count];  // cycle
        }
    }
}
