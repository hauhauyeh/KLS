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

        public IQueryable<PurchaseOrderList> GetPurchaseOrders(PurchaseOrderReq purchaseOrderReq)
        {
            var param = BuildPurchaseOrdersParam(purchaseOrderReq);

            return DbContext.PurchaseOrderList.FromSqlRaw("[dbo].[PurchaseOrder_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@PayeeId,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int CountAllPurchaseOrders(PurchaseOrderReq purchaseOrderReq)
        {
            purchaseOrderReq.IsCount = true;
            var param = BuildPurchaseOrdersParam(purchaseOrderReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[PurchaseOrder_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@PayeeId,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[10] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        private static object[] BuildPurchaseOrdersParam(PurchaseOrderReq purchaseOrderReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", purchaseOrderReq.Pageno),

                new SqlParameter("@Pagesize", purchaseOrderReq.Pagesize),

                string.IsNullOrEmpty(purchaseOrderReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", purchaseOrderReq.Search),

                purchaseOrderReq.StartDate.HasValue ? new SqlParameter("@StartDate", purchaseOrderReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                purchaseOrderReq.EndDate.HasValue ? new SqlParameter("@EndDate", purchaseOrderReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                 purchaseOrderReq.PayeeId.HasValue ? new SqlParameter("@PayeeId", purchaseOrderReq.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value),

                string.IsNullOrEmpty(purchaseOrderReq.Filterby) ? new SqlParameter("@Filterby", DBNull.Value) : new SqlParameter("@Filterby", purchaseOrderReq.Filterby),

                string.IsNullOrEmpty(purchaseOrderReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", purchaseOrderReq.SortField),

                string.IsNullOrEmpty(purchaseOrderReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", purchaseOrderReq.SortOrder),

                new SqlParameter("@IsCount", purchaseOrderReq.IsCount),

                new SqlParameter()
                {
                    ParameterName = "@TotalCount",
                    Direction = System.Data.ParameterDirection.Output,
                    SqlDbType = System.Data.SqlDbType.Int
                }
            };

            return param;
        }

        public void InjectPurchaseOrder(PurchaseOrderInjectReq injectReq)
        {
            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var PayeeIdParam = new SqlParameter("@PayeeId", injectReq.PayeeId);

            var POIdParam = new SqlParameter("@POId", injectReq.POId);

            DbContext.Database.ExecuteSqlRaw("[PurchaseOrder_Inject] @EmpId,@PayeeId,@POId", EmpIdParam, PayeeIdParam, POIdParam);
        }

        public int Checkout(PurchaseOrderCheckoutReq checkoutReq)
        {
            // int parameters
            var POIdParam = new SqlParameter("@POId", (object?)checkoutReq.POId ?? 0);

            var PayeeIdParam = new SqlParameter("@PayeeId", checkoutReq.PayeeId);

            // date parameters
            object ToDbDate(DateOnly? d) => d.HasValue ? d.Value.ToDateTime(TimeOnly.MinValue) : DBNull.Value;

            var PurchaseDateParam = checkoutReq.PurchaseDate.HasValue
                ? new SqlParameter("@PurchaseDate", ToDbDate(checkoutReq.PurchaseDate))
                : new SqlParameter("@PurchaseDate", DBNull.Value);

            var EstArrivalDateParam = checkoutReq.EstArrivalDate.HasValue
                ? new SqlParameter("@EstArrivalDate", ToDbDate(checkoutReq.EstArrivalDate))
                : new SqlParameter("@EstArrivalDate", DBNull.Value);

            // notes
            var NotesParam = string.IsNullOrWhiteSpace(checkoutReq.Notes)
                ? new SqlParameter("@Notes", DBNull.Value)
                : new SqlParameter("@Notes", checkoutReq.Notes);

            // emp

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            // output
            var NewPOIdParam = new SqlParameter
            {
                ParameterName = "@NewPOId",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };

            DbContext.Database.ExecuteSqlRaw("[PurchaseOrder_Insert] @POId,@PayeeId,@PurchaseDate,@EstArrivalDate,@Notes,@EmpId,@NewPOId OUTPUT", POIdParam, PayeeIdParam, PurchaseDateParam, EstArrivalDateParam, NotesParam, EmpIdParam, NewPOIdParam);

            return (NewPOIdParam.Value == DBNull.Value) ? 0 : Convert.ToInt32(NewPOIdParam.Value);
        }

        public void SaveAdvancePayment(POAdvancePaymentReq advancePaymentReq)
        {
            var POIdParam = new SqlParameter("@POId", advancePaymentReq.POId);

            var PaymentDateParam = advancePaymentReq.PaymentDate.HasValue
                ? new SqlParameter("@PaymentDate", advancePaymentReq.PaymentDate)
                : new SqlParameter("@PaymentDate", DBNull.Value);

            var PaymentMethodParam = (!string.IsNullOrEmpty(advancePaymentReq.PaymentMethod))
                ? new SqlParameter("@PaymentMethod", advancePaymentReq.PaymentMethod)
                : new SqlParameter("@PaymentMethod", DBNull.Value);

            var FromAccountIdParam = new SqlParameter("@FromAccountId", advancePaymentReq.FromAccountId);

            var AdvanceTotalParam = advancePaymentReq.AdvanceTotal.HasValue
                ? new SqlParameter("@AdvanceTotal", advancePaymentReq.AdvanceTotal)
                : new SqlParameter("@AdvanceTotal", DBNull.Value);

            DbContext.Database.ExecuteSqlRaw("[dbo].[PurchaseOrder_InsertAdvance] @POId,@PaymentDate,@PaymentMethod,@FromAccountId,@AdvanceTotal", POIdParam, PaymentDateParam, PaymentMethodParam, FromAccountIdParam, AdvanceTotalParam);
        }

        public void DeleteAdvancePayment(int poId)
        {
            var POIdParam = new SqlParameter("@POId", poId);

            DbContext.Database.ExecuteSqlRaw("[dbo].[PurchaseOrder_DeleteAdvance] @POId", POIdParam);
        }
    }
}
