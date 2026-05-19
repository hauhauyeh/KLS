using KLS.Contract.Dtos.Item;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IItemUnitService
    {
        List<ItemUnit> GetByItemId(int itemId);

        ItemUnit GetBaseUnit(int itemId);

        ItemUnit GetSalesUnit(int itemId);

        ItemUnit GetNextUnit(int itemId, string unit);

        ItemPrice GetItemPriceByCustomer(int payeeId, int itemId, int? itemUnitId);

        ItemUnit? ResolveKeyboxUnit(int itemId, string? keyboxUnit);

        IEnumerable<ItemUnitListRow> GetUnitViewList(string itemIds);

        ItemUnitMutationResult CreateUnit(int itemId);

        ItemUnitMutationResult UpdateUnit(ItemUnitUpdateReq req);

        ItemUnitMutationResult DeleteUnit(int itemUnitId);
    }
}
