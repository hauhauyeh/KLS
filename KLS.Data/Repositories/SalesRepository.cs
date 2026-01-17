using KLS.Common;
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
    public class SalesRepository : KLSRepository<Sales>, ISalesRepository
    {
        public SalesRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<SalesList> GetPagedList(SalesListReq salesListReq)
        {
            var param = BuildSalesParam(salesListReq);

            return DbContext.SalesList.FromSqlRaw("[dbo].[Sales_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@PayeeId,@ShipRoute,@Id,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int Count(SalesListReq salesListReq)
        {
            salesListReq.IsCount = true;
            var param = BuildSalesParam(salesListReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[Sales_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@PayeeId,@ShipRoute,@Id,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[11] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        private static object[] BuildSalesParam(SalesListReq salesListReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", salesListReq.Pageno),

                new SqlParameter("@Pagesize", salesListReq.Pagesize),

                string.IsNullOrEmpty(salesListReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", salesListReq.Search),

                salesListReq.StartDate.HasValue ? new SqlParameter("@StartDate", salesListReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                salesListReq.EndDate.HasValue ? new SqlParameter("@EndDate", salesListReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                 salesListReq.PayeeId.HasValue ? new SqlParameter("@PayeeId", salesListReq.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value),

                string.IsNullOrEmpty(salesListReq.ShipRoute) ? new SqlParameter("@ShipRoute", DBNull.Value) : new SqlParameter("@ShipRoute", salesListReq.ShipRoute),

                salesListReq.Id.HasValue ? new SqlParameter("@Id", salesListReq.Id) : new SqlParameter("@Id", DBNull.Value),

                string.IsNullOrEmpty(salesListReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", salesListReq.SortField),

                string.IsNullOrEmpty(salesListReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", salesListReq.SortOrder),

                new SqlParameter("@IsCount", salesListReq.IsCount),

                new SqlParameter()
                {
                    ParameterName = "@TotalCount",
                    Direction = System.Data.ParameterDirection.Output,
                    SqlDbType = System.Data.SqlDbType.Int
                }
            };

            return param;
        }

        public void Inject(int salesId)
        {
            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var SalesIdParam = new SqlParameter("@SalesId", salesId);

            DbContext.Database.ExecuteSqlRaw("[Sales_Inject] @EmpId,@SalesId", EmpIdParam, SalesIdParam);
        }

        public int Checkout(SalesCheckoutReq checkoutReq)
        {
            var SalesIdParam = new SqlParameter("@SalesId", checkoutReq.SalesId);

            var PayeeIdParam = new SqlParameter("@PayeeId", checkoutReq.PayeeId);

            var ShipDateParam = checkoutReq.ShipDate.HasValue ? new SqlParameter("@ShipDate", checkoutReq.ShipDate) : new SqlParameter("@ShipDate", DBNull.Value);

            var ShipRouteParam = (!string.IsNullOrEmpty(checkoutReq.ShipRoute)) ? new SqlParameter("@ShipRoute", checkoutReq.ShipRoute) : new SqlParameter("@ShipRoute", DBNull.Value);

            var InstructionParam = (!string.IsNullOrEmpty(checkoutReq.Instruction)) ? new SqlParameter("@Instruction", checkoutReq.Instruction) : new SqlParameter("@Instruction", DBNull.Value);

            var StageIdParam = checkoutReq.StageId.HasValue ? new SqlParameter("@StageId", checkoutReq.StageId) : new SqlParameter("@StageId", DBNull.Value);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var NewSalesId = new SqlParameter()
            {
                ParameterName = "@NewSalesId",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };

            DbContext.Database.ExecuteSqlRaw("[Sales_Insert] @SalesId,@PayeeId,@ShipDate,@ShipRoute,@Instruction,@StageId,@EmpId,@NewSalesId OUTPUT", SalesIdParam, PayeeIdParam, ShipDateParam, ShipRouteParam, InstructionParam, StageIdParam, EmpIdParam, NewSalesId);

            return Convert.ToInt32(NewSalesId.Value);
        }

        public void UpdatePartially(int salesId)
        {
            var SalesIdParam = new SqlParameter("@SalesId", salesId);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            DbContext.Database.ExecuteSqlRaw("[Sales_PartialUpdate] @SalesId,@EmpId", SalesIdParam, EmpIdParam);
        }

        public void UpdateNameDate(SalesUpdateReq updateReq)
        {
            var SalesIdParam = new SqlParameter("@SalesId", updateReq.SalesId);

            var IsNameChangeParam = new SqlParameter("@IsNameChange", updateReq.IsNameChange);

            var PayeeIdParam = updateReq.PayeeId.HasValue
                ? new SqlParameter("@PayeeId", updateReq.PayeeId)
                : new SqlParameter("@PayeeId", DBNull.Value);

            var IsDateChangeParam = new SqlParameter("@IsDateChange", updateReq.IsDateChange);

            var ShipDateParam = updateReq.ShipDate.HasValue
                ? new SqlParameter("@ShipDate", updateReq.ShipDate)
                : new SqlParameter("@ShipDate", DBNull.Value);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            DbContext.Database.ExecuteSqlRaw("[Sales_Update] @SalesId,@IsNameChange,@PayeeId,@IsDateChange,@ShipDate,@EmpId", SalesIdParam, IsNameChangeParam, PayeeIdParam, IsDateChangeParam, ShipDateParam, EmpIdParam);
        }

        public void InsertShippingCharge(SalesUpdateReq updateReq)
        {
            var SalesIdParam = new SqlParameter("@SalesId", updateReq.SalesId);

            var ShippingChargeParam = updateReq.ShippingCharge.HasValue
                ? new SqlParameter("@ShippingCharge", updateReq.ShippingCharge)
                : new SqlParameter("@ShippingCharge", DBNull.Value);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            DbContext.Database.ExecuteSqlRaw("[Sales_InsertShippingCharge] @SalesId,@ShippingCharge,@EmpId", SalesIdParam, ShippingChargeParam, EmpIdParam);
        }

        public IQueryable<ShipRouteSummary>? ShipRouteSummary(DateOnly shipDate)
        {
            var ShipDateParam = new SqlParameter("@ShipDate", shipDate);

            return DbContext.ShipRouteSummary.FromSqlRaw("[Sales_ShipRouteSummary] @ShipDate", ShipDateParam);
        }

        public IQueryable<ShipRouteDetail>? ShipRouteDetail(DateOnly shipDate)
        {
            var ShipDateParam = new SqlParameter("@ShipDate", shipDate);

            return DbContext.ShipRouteDetail.FromSqlRaw("[Sales_ShipRouteDetail] @ShipDate", ShipDateParam);
        }

        public IQueryable<ShipRouteDetail>? GetByDateRoute(SalesDateRouteReq dateRouteReq)
        {
            var ShipDateParam = new SqlParameter("@ShipDate", dateRouteReq.ShipDate);

            var ShipRouteParam = (!string.IsNullOrEmpty(dateRouteReq.ShipRoute)) ? new SqlParameter("@ShipRoute", dateRouteReq.ShipRoute) : new SqlParameter("@ShipRoute", DBNull.Value);

            return DbContext.ShipRouteDetail.FromSqlRaw("[Sales_GetByDateRoute] @ShipDate,@ShipRoute", ShipDateParam, ShipRouteParam);
        }
    }
}