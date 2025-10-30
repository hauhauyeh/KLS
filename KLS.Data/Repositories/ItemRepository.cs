using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Data.Repositories;
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
    public class ItemRepository : KLSRepository<Item>, IItemRepository
    {
        public ItemRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<ItemList> GetItems(ItemListReq itemListReq)
        {
            var param = BuildGetItemsParam(itemListReq);

            return DbContext.ItemList.FromSqlRaw("[dbo].[Item_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int CountAllItems(ItemListReq itemListReq)
        {
            itemListReq.IsCount = true;
            var param = BuildGetItemsParam(itemListReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[Item_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[9] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        private static object[] BuildGetItemsParam(ItemListReq itemListReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", itemListReq.Pageno),

                new SqlParameter("@Pagesize", itemListReq.Pagesize),

                string.IsNullOrEmpty(itemListReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", itemListReq.Search),

                itemListReq.StartDate.HasValue ? new SqlParameter("@StartDate", itemListReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                itemListReq.EndDate.HasValue ? new SqlParameter("@EndDate", itemListReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                string.IsNullOrEmpty(itemListReq.Filterby) ? new SqlParameter("@Filterby", DBNull.Value) : new SqlParameter("@Filterby", itemListReq.Filterby),

                string.IsNullOrEmpty(itemListReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", itemListReq.SortField),

                string.IsNullOrEmpty(itemListReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", itemListReq.SortOrder),

                new SqlParameter("@IsCount", itemListReq.IsCount),

                new SqlParameter()
                {
                    ParameterName = "@TotalCount",
                    Direction = System.Data.ParameterDirection.Output,
                    SqlDbType = System.Data.SqlDbType.Int
                }
            };

            return param;
        }


        public IQueryable<ItemSearch>? SearchItem(ItemSearchReq searchReq)
        {
            var TermParam = string.IsNullOrEmpty(searchReq.Term) ? new SqlParameter("@SearchTerm", DBNull.Value) : new SqlParameter("@SearchTerm", searchReq.Term);

            var IsActiveOnlyParam = new SqlParameter("@IsActiveOnly", searchReq.IsActiveOnly);

            return DbContext.ItemSearch.FromSqlRaw("[dbo].[Item_SearchByTerm] @SearchTerm,@IsActiveOnly", TermParam, IsActiveOnlyParam);
        }
    }
}