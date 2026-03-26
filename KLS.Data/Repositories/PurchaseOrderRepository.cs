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
    public class PurchaseOrderRepository : KLSRepository<PurchaseOrder>, IPurchaseOrderRepository
    {
        public PurchaseOrderRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<POList> GetPagedList(POListReq purchaseOrderReq)
        {
            var param = BuildParam(purchaseOrderReq);

            return DbContext.POList.FromSqlRaw("[dbo].[PurchaseOrder_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@VendorId,@EmpId,@Filterby,@Id,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int Count(POListReq purchaseOrderReq)
        {
            purchaseOrderReq.IsCount = true;
            var param = BuildParam(purchaseOrderReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[PurchaseOrder_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@VendorId,@EmpId,@Filterby,@Id,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[11] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        private static object[] BuildParam(POListReq poReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", poReq.Pageno),

                new SqlParameter("@Pagesize", poReq.Pagesize),

                string.IsNullOrEmpty(poReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", poReq.Search),

                poReq.StartDate.HasValue ? new SqlParameter("@StartDate", poReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                poReq.EndDate.HasValue ? new SqlParameter("@EndDate", poReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                poReq.PayeeId.HasValue ? new SqlParameter("@VendorId", poReq.PayeeId) : new SqlParameter("@VendorId", DBNull.Value),

                new SqlParameter("@EmpId", UserContext.EmpId),

                string.IsNullOrEmpty(poReq.Filterby) ? new SqlParameter("@Filterby", DBNull.Value) : new SqlParameter("@Filterby", poReq.Filterby),

                poReq.Id.HasValue ? new SqlParameter("@Id", poReq.Id) : new SqlParameter("@Id", DBNull.Value),

                string.IsNullOrEmpty(poReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", poReq.SortField),

                string.IsNullOrEmpty(poReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", poReq.SortOrder),

                new SqlParameter("@IsCount", poReq.IsCount),

                new SqlParameter()
                {
                    ParameterName = "@TotalCount",
                    Direction = System.Data.ParameterDirection.Output,
                    SqlDbType = System.Data.SqlDbType.Int
                }
            };

            return param;
        }

        public void Inject(POInjectReq injectReq)
        {
            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var PayeeIdParam = new SqlParameter("@PayeeId", injectReq.PayeeId);

            var PurchaseIdParam = new SqlParameter("@PurchaseId", injectReq.PurchaseId);

            DbContext.Database.ExecuteSqlRaw("[PurchaseOrder_Inject] @EmpId,@PayeeId,@PurchaseId", EmpIdParam, PayeeIdParam, PurchaseIdParam);
        }

        public int Checkout(POCheckoutReq checkoutReq)
        {
            var PurchaseIdParam = new SqlParameter("@PurchaseId", checkoutReq.PurchaseId);

            var PayeeIdParam = new SqlParameter("@PayeeId", checkoutReq.PayeeId);

            var PurchaseDateParam = checkoutReq.PurchaseDate.HasValue
                ? new SqlParameter("@PurchaseDate", checkoutReq.PurchaseDate)
                : new SqlParameter("@PurchaseDate", DBNull.Value);

            var ArrivalDateParam = checkoutReq.ArrivalDate.HasValue
                ? new SqlParameter("@ArrivalDate", checkoutReq.ArrivalDate)
                : new SqlParameter("@ArrivalDate", DBNull.Value);

            var NotesParam = string.IsNullOrWhiteSpace(checkoutReq.Notes)
                ? new SqlParameter("@Notes", DBNull.Value)
                : new SqlParameter("@Notes", checkoutReq.Notes);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var NewPOIdParam = new SqlParameter
            {
                ParameterName = "@NewPOId",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };

            DbContext.Database.ExecuteSqlRaw("[PurchaseOrder_Insert] @PurchaseId,@PayeeId,@PurchaseDate,@ArrivalDate,@Notes,@EmpId,@NewPOId OUTPUT", PurchaseIdParam, PayeeIdParam, PurchaseDateParam, ArrivalDateParam, NotesParam, EmpIdParam, NewPOIdParam);

            return Convert.ToInt32(NewPOIdParam.Value);
        }

        public IQueryable<PODetail> GetPODetail(int purchaseId)
        {
            var PurchaseIdParam = new SqlParameter("@PurchaseId", purchaseId);

            return DbContext.PODetail.FromSqlRaw("[dbo].[PurchaseOrder_GetDetail] @PurchaseId", PurchaseIdParam);
        }

        public void CopyToBill(POCopyToBillReq copyToBillReq)
        {
            var POIdParam = new SqlParameter("@PurchaseId", copyToBillReq.PurchaseId);

            var PayeeIdParam = new SqlParameter("@ItemsJson", copyToBillReq.ItemsJson);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var ShipmentIdsParam = (!string.IsNullOrEmpty(copyToBillReq.ShipmentIds))
                ? new SqlParameter("@ShipmentIds", copyToBillReq.ShipmentIds)
                : new SqlParameter("@ShipmentIds", DBNull.Value);

            DbContext.Database.ExecuteSqlRaw("[PurchaseOrder_CopyToBill] @PurchaseId,@ItemsJson,@EmpId,@ShipmentIds", EmpIdParam, PayeeIdParam, POIdParam, ShipmentIdsParam);
        }
    }
}
