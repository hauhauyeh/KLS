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
    public class ItemTariffRepository : KLSRepository<ItemTariff>, IItemTariffRepository
    {
        public ItemTariffRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        public IQueryable<ItemTariffList> GetPagedList(ItemTariffListReq tariffListReq)
        {
            var param = BuildPagedList(tariffListReq);

            return DbContext.ItemTariffList.FromSqlRaw("[dbo].[ItemTariff_GetAllList] @Pageno, @Pagesize, @Search, @SortField, @SortOrder, @IsCount, @TotalCount OUTPUT", param);
        }

        public int Count(ItemTariffListReq tariffListReq)
        {
            tariffListReq.IsCount = true;
            var param = BuildPagedList(tariffListReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[ItemTariff_GetAllList] @Pageno, @Pagesize, @Search, @SortField, @SortOrder, @IsCount, @TotalCount OUTPUT", param);

            var output = (SqlParameter)param[6];
            return output.Value == DBNull.Value ? 0 : Convert.ToInt32(output.Value);
        }

        private static object[] BuildPagedList(ItemTariffListReq tariffListReq)
        {
            object[] param =
            {
                new SqlParameter("@Pageno", tariffListReq.Pageno),
                new SqlParameter("@Pagesize", tariffListReq.Pagesize),

                string.IsNullOrWhiteSpace(tariffListReq.Search)
                    ? new SqlParameter("@Search", DBNull.Value)
                    : new SqlParameter("@Search", tariffListReq.Search),

                string.IsNullOrWhiteSpace(tariffListReq.SortField)
                    ? new SqlParameter("@SortField", DBNull.Value)
                    : new SqlParameter("@SortField", tariffListReq.SortField),

                string.IsNullOrWhiteSpace(tariffListReq.SortOrder)
                    ? new SqlParameter("@SortOrder", DBNull.Value)
                    : new SqlParameter("@SortOrder", tariffListReq.SortOrder),

                new SqlParameter("@IsCount", tariffListReq.IsCount),

                new SqlParameter
                {
                    ParameterName = "@TotalCount",
                    Direction = ParameterDirection.Output,
                    SqlDbType = SqlDbType.Int
                }
            };

            return param;
        }
    }
}
