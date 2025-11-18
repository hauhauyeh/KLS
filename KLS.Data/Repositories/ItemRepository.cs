using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Data.Repositories;
using KLS.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Data;
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

        public IQueryable<ItemList> GetAllItems(ItemListReq itemListReq)
        {
            var param = BuildGetItemsParam(itemListReq);

            return DbContext.ItemList.FromSqlRaw("[dbo].[Item_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@Filterby,@Content,@Id,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int CountAllItems(ItemListReq itemListReq)
        {
            itemListReq.IsCount = true;
            var param = BuildGetItemsParam(itemListReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[Item_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@Filterby,@Content,@Id,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[11] as SqlParameter;
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

                string.IsNullOrEmpty(itemListReq.Content) ? new SqlParameter("@Content", DBNull.Value) : new SqlParameter("@Content", itemListReq.Content),

                itemListReq.Id.HasValue ? new SqlParameter("@Id", itemListReq.Id) : new SqlParameter("@Id", DBNull.Value),

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

        public void DeleteItem(int itemId)
        {
            var ItemIdParam = new SqlParameter("@ItemId", itemId);

            DbContext.Database.ExecuteSqlRaw("[Item_Delete] @ItemId", ItemIdParam);
        }

        public ItemCalcUnit GetCalcUnit(ItemPackingReq packingReq)
        {
            var Pack1Param = string.IsNullOrEmpty(packingReq.Pack1) ? new SqlParameter("@Pack1", DBNull.Value) : new SqlParameter("@Pack1", packingReq.Pack1);

            var P1Param = packingReq.P1.HasValue ? new SqlParameter("@P1", packingReq.P1) : new SqlParameter("@P1", DBNull.Value);

            var RetailProfitPercentParam = packingReq.RetailProfitPercent.HasValue ? new SqlParameter("@RetailProfitPercent", packingReq.RetailProfitPercent) : new SqlParameter("@RetailProfitPercent", DBNull.Value);

            return DbContext.ItemCalcUnit.FromSqlRaw("[Item_CalcUnitFromPack1] @Pack1,@P1,@RetailProfitPercent", Pack1Param, P1Param, RetailProfitPercentParam).AsEnumerable().FirstOrDefault()!;
        }

        public ItemCalcRetail CalcRetailPriceProfit(ItemCalcRetail calcRetail)
        {
            var P1Param = calcRetail.P1.HasValue ? new SqlParameter("@P1", calcRetail.P1) : new SqlParameter("@P1", DBNull.Value);

            var RetailUnitParam = string.IsNullOrEmpty(calcRetail.RetailUnit) ? new SqlParameter("@RetailUnit", DBNull.Value) : new SqlParameter("@RetailUnit", calcRetail.RetailUnit);

            var RetailFactorParam = calcRetail.RetailFactor.HasValue ? new SqlParameter("@RetailFactor", calcRetail.RetailFactor) : new SqlParameter("@RetailFactor", DBNull.Value);

            var RetailPriceParam = new SqlParameter("@RetailPrice", SqlDbType.Decimal)
            {
                Direction = ParameterDirection.InputOutput, // or Output if you never send initial value
                Precision = 18,
                Scale = 2,
                Value = (object?)calcRetail.RetailPrice ?? DBNull.Value
            };

            var RetailProfitPercentParam = new SqlParameter("@RetailProfitPercent", SqlDbType.Decimal)
            {
                Direction = ParameterDirection.InputOutput, // or Output
                Precision = 18,
                Scale = 4,
                Value = (object?)calcRetail.RetailProfitPercent ?? DBNull.Value
            };

            DbContext.Database.ExecuteSqlRaw("[Item_CalcRetailPriceAndProfit] @P1,@RetailUnit,@RetailFactor,@RetailPrice OUTPUT,@RetailProfitPercent OUTPUT", P1Param, RetailUnitParam, RetailFactorParam, RetailPriceParam, RetailProfitPercentParam);

            if (RetailPriceParam.Value != DBNull.Value && RetailPriceParam.Value != null)
                calcRetail.RetailPrice = Convert.ToDecimal(RetailPriceParam.Value);

            if (RetailProfitPercentParam.Value != DBNull.Value && RetailProfitPercentParam.Value != null)
                calcRetail.RetailProfitPercent = Convert.ToDecimal(RetailProfitPercentParam.Value);

            return calcRetail;
        }
    }
}