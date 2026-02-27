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
    public class PromotionRepository : KLSRepository<Promotion>, IPromotionRepository
    {
        public PromotionRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<PromotionList> GetPagedList(PromotionListReq promotionListReq)
        {
            var param = BuildParam(promotionListReq);

            return DbContext.PromotionList.FromSqlRaw("[dbo].[Promotion_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int Count(PromotionListReq promotionListReq)
        {
            promotionListReq.IsCount = true;
            var param = BuildParam(promotionListReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[Promotion_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[9] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        private static object[] BuildParam(PromotionListReq promotionListReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", promotionListReq.Pageno),

                new SqlParameter("@Pagesize", promotionListReq.Pagesize),

                string.IsNullOrEmpty(promotionListReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", promotionListReq.Search),

                promotionListReq.StartDate.HasValue ? new SqlParameter("@StartDate", promotionListReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                promotionListReq.EndDate.HasValue ? new SqlParameter("@EndDate", promotionListReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                string.IsNullOrEmpty(promotionListReq.Filterby) ? new SqlParameter("@Filterby", DBNull.Value) : new SqlParameter("@Filterby", promotionListReq.Filterby),

                string.IsNullOrEmpty(promotionListReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", promotionListReq.SortField),

                string.IsNullOrEmpty(promotionListReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", promotionListReq.SortOrder),

                new SqlParameter("@IsCount", promotionListReq.IsCount),

                new SqlParameter()
                {
                    ParameterName = "@TotalCount",
                    Direction = System.Data.ParameterDirection.Output,
                    SqlDbType = System.Data.SqlDbType.Int
                }
            };

            return param;
        }
    }
}
