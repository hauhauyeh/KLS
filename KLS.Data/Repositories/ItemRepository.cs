using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
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

        public IQueryable<ItemList> GetPagedList(ItemListReq itemListReq)
        {
            var param = BuildParam(itemListReq);

            return DbContext.ItemList.FromSqlRaw("[dbo].[Item_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@VendorId,@Container,@CategoryId,@Filterby,@Id,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int Count(ItemListReq itemListReq)
        {
            itemListReq.IsCount = true;
            var param = BuildParam(itemListReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[Item_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@VendorId,@Container,@CategoryId,@Filterby,@Id,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[13] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        private static object[] BuildParam(ItemListReq itemListReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", itemListReq.Pageno),

                new SqlParameter("@Pagesize", itemListReq.Pagesize),

                string.IsNullOrEmpty(itemListReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", itemListReq.Search),

                itemListReq.StartDate.HasValue ? new SqlParameter("@StartDate", itemListReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                itemListReq.EndDate.HasValue ? new SqlParameter("@EndDate", itemListReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                itemListReq.VendorId.HasValue ? new SqlParameter("@VendorId", itemListReq.VendorId) : new SqlParameter("@VendorId", DBNull.Value),

                string.IsNullOrEmpty(itemListReq.Container) ? new SqlParameter("@Container", DBNull.Value) : new SqlParameter("@Container", itemListReq.Container),

                itemListReq.CategoryId.HasValue ? new SqlParameter("@CategoryId", itemListReq.CategoryId) : new SqlParameter("@CategoryId", DBNull.Value),

                string.IsNullOrEmpty(itemListReq.Filterby) ? new SqlParameter("@Filterby", DBNull.Value) : new SqlParameter("@Filterby", itemListReq.Filterby),

                itemListReq.Id.HasValue ? new SqlParameter("@Id", itemListReq.Id) : new SqlParameter("@Id", DBNull.Value),

                string.IsNullOrEmpty(itemListReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", itemListReq.SortField),

                string.IsNullOrEmpty(itemListReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", itemListReq.SortOrder),

                new SqlParameter("@IsCount", itemListReq.IsCount),

                new SqlParameter()
                {
                    ParameterName = "@TotalCount",
                    Direction = ParameterDirection.Output,
                    SqlDbType = SqlDbType.Int
                }
            };

            return param;
        }

        public IQueryable<ItemSearch>? Search(ItemSearchReq searchReq)
        {
            var TermParam = string.IsNullOrEmpty(searchReq.Term) ? new SqlParameter("@SearchTerm", DBNull.Value) : new SqlParameter("@SearchTerm", searchReq.Term);

            var IsActiveOnlyParam = new SqlParameter("@IsActiveOnly", searchReq.IsActiveOnly);

            return DbContext.ItemSearch.FromSqlRaw("[dbo].[Item_SearchByTerm] @SearchTerm,@IsActiveOnly", TermParam, IsActiveOnlyParam);
        }

        public void Delete(int itemId)
        {
            var ItemIdParam = new SqlParameter("@ItemId", itemId);

            DbContext.Database.ExecuteSqlRaw("[Item_Delete] @ItemId", ItemIdParam);
        }

        public IQueryable<ItemCalcUnit> GetCalcUnit(ItemPackingReq packingReq)
        {
            var SetPackingParam = string.IsNullOrEmpty(packingReq.SetPacking) ? new SqlParameter("@SetPacking", DBNull.Value) : new SqlParameter("@SetPacking", packingReq.SetPacking);

            var P1Param = packingReq.P1.HasValue ? new SqlParameter("@P1", packingReq.P1) : new SqlParameter("@P1", DBNull.Value);

            return DbContext.ItemCalcUnit.FromSqlRaw("[Item_CalcUnitFromPack1] @SetPacking,@P1", SetPackingParam, P1Param);
        }

        public ItemCalcRetail CalcRetailPriceProfit(ItemCalcRetail calcRetail)
        {
            var P1Param = calcRetail.P1.HasValue ? new SqlParameter("@P1", calcRetail.P1) : new SqlParameter("@P1", DBNull.Value);

            var FactorToBaseParam = calcRetail.FactorToBase.HasValue ? new SqlParameter("@FactorToBase", calcRetail.FactorToBase) : new SqlParameter("@FactorToBase", DBNull.Value);

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

            DbContext.Database.ExecuteSqlRaw("[Item_CalcRetailPriceAndProfit] @P1,@FactorToBase,@RetailPrice OUTPUT,@RetailProfitPercent OUTPUT", P1Param, FactorToBaseParam, RetailPriceParam, RetailProfitPercentParam);

            if (RetailPriceParam.Value != DBNull.Value && RetailPriceParam.Value != null)
                calcRetail.RetailPrice = Convert.ToDecimal(RetailPriceParam.Value);

            if (RetailProfitPercentParam.Value != DBNull.Value && RetailProfitPercentParam.Value != null)
                calcRetail.RetailProfitPercent = Convert.ToDecimal(RetailProfitPercentParam.Value);

            return calcRetail;
        }

        public void UpdateBaseP1(ItemUpdateReq updateReq)
        {
            var ItemUnitIdParam = new SqlParameter("@ItemUnitId", updateReq.ItemUnitId);

            var BaseP1Param = updateReq.BaseP1.HasValue ? new SqlParameter("@BaseP1", updateReq.BaseP1) : new SqlParameter("@BaseP1", DBNull.Value);

            DbContext.Database.ExecuteSqlRaw("[Item_UpdateBaseP1] @ItemUnitId,@BaseP1", ItemUnitIdParam, BaseP1Param);
        }

        public ItemDefaultFreight GetDefaultFreight(int itemId)
        {
            var ItemIdParam = new SqlParameter("@ItemId", itemId);

            return DbContext.ItemDefaultFreight.FromSqlRaw("[Item_GetDefaultFreight] @ItemId", ItemIdParam).ToList().FirstOrDefault();
        }
    }
}