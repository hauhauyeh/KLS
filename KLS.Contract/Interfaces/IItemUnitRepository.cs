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
    }
}
