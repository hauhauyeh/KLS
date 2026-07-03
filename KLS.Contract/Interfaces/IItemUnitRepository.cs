using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface IItemUnitRepository : IRepository<ItemUnit>
    {
        ItemPrice GetItemPriceByCustomer(int payeeId, int itemId, int? itemUnitId);

        IEnumerable<ItemUnitListRow> GetUnitViewList(string itemIds);

        void Delete(int itemUnitId);

        // True if the unit is referenced in any of the 13 ItemUnitId tables (incl. Temp* drafts).
        // Used by the DeleteUnit guard: delete only UNUSED units; used ones must be inactivated.
        bool IsUsed(int itemUnitId);
    }
}
