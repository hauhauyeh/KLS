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
    public class ItemHistoryRepository : KLSRepository<ItemHistorySales>, IItemHistoryRepository
    {
        public ItemHistoryRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<ItemHistorySales> GetSalesHistory(ItemHistoryReq itemHistoryReq)
        {
            var ItemIdParam = new SqlParameter("@ItemId", itemHistoryReq.ItemId);

            var PayeeIdParam = new SqlParameter("@PayeeId", itemHistoryReq.PayeeId);

            var FilterbyParam = (!string.IsNullOrEmpty(itemHistoryReq.Filterby)) ? new SqlParameter("@Filterby", itemHistoryReq.Filterby) : new SqlParameter("@Filterby", DBNull.Value);

            return DbContext.ItemHistorySales.FromSqlRaw("[dbo].[ItemHistory_Sales] @ItemId,@PayeeId,@Filterby", ItemIdParam, PayeeIdParam, FilterbyParam);
        }

        public IQueryable<ItemHistoryPurchase> GetPurchaseHistory(ItemHistoryReq itemHistoryReq)
        {
            var ItemIdParam = new SqlParameter("@ItemId", itemHistoryReq.ItemId);

            var PayeeIdParam = new SqlParameter("@PayeeId", itemHistoryReq.PayeeId);

            return DbContext.ItemHistoryPurchase.FromSqlRaw("[dbo].[ItemHistory_Purchase] @ItemId,@PayeeId", ItemIdParam, PayeeIdParam);
        }
    }
}
