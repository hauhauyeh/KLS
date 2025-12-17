using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface IItemUnitService
    {
        List<ItemUnit> GetByItemId(int itemId);

        ItemUnit GetBaseUnit(int itemId);

        ItemUnit GetNextUnit(int itemId, string unit);
    }
}
