using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Data.Repositories
{
    public class ItemUnitRepository : KLSRepository<ItemUnit>, IItemUnitRepository
    {
        public ItemUnitRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        public ItemPrice GetItemPriceByCustomer(int payeeId, int itemId, int? itemUnitId)
        {
            var PayeeIdParam = new SqlParameter("@PayeeId", payeeId);

            var ItemIdParam = new SqlParameter("@ItemId", itemId);

            var ItemUnitIdParam = itemUnitId.HasValue ? new SqlParameter("@ItemUnitId", itemUnitId) : new SqlParameter("@ItemUnitId", DBNull.Value);

            return DbContext.ItemPrice.FromSqlRaw("[Get_ItemPriceByCustomer] @PayeeId,@ItemId,@ItemUnitId", PayeeIdParam, ItemIdParam, ItemUnitIdParam).AsEnumerable().FirstOrDefault();
        }
    }
}
