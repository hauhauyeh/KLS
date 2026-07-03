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

        public IEnumerable<ItemUnitListRow> GetUnitViewList(string itemIds)
        {
            var param = new SqlParameter("@ItemIds", (object?)itemIds ?? DBNull.Value);

            return DbContext.ItemUnitListRow
                .FromSqlRaw("EXEC [dbo].[ItemUnit_GetViewList] @ItemIds", param)
                .AsNoTracking()
                .ToList();
        }

        public ItemPrice GetItemPriceByCustomer(int payeeId, int itemId, int? itemUnitId)
        {
            var PayeeIdParam = new SqlParameter("@PayeeId", payeeId);

            var ItemIdParam = new SqlParameter("@ItemId", itemId);

            var ItemUnitIdParam = itemUnitId.HasValue ? new SqlParameter("@ItemUnitId", itemUnitId) : new SqlParameter("@ItemUnitId", DBNull.Value);

            return DbContext.ItemPrice.FromSqlRaw("[Get_ItemPriceByCustomer] @PayeeId,@ItemId,@ItemUnitId", PayeeIdParam, ItemIdParam, ItemUnitIdParam).AsEnumerable().FirstOrDefault();
        }

        public void Delete(int itemUnitId)
        {
            var ItemUnitIdParam = new SqlParameter("@ItemUnitId", itemUnitId);

            DbContext.Database.ExecuteSqlRaw("EXEC [dbo].[ItemUnit_Delete] @ItemUnitId", ItemUnitIdParam);
        }

        public bool IsUsed(int itemUnitId)
        {
            var param = new SqlParameter("@ItemUnitId", itemUnitId);

            // Fn_ItemUnit_IsUsed returns a BIT (all 13 ItemUnitId tables, incl. Temp* drafts) -> read as bool.
            return DbContext.Database
                .SqlQueryRaw<bool>("SELECT dbo.Fn_ItemUnit_IsUsed(@ItemUnitId) AS Value", param)
                .AsEnumerable()
                .First();
        }
    }
}
