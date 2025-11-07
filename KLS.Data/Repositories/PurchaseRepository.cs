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
    public class PurchaseRepository : KLSRepository<Purchase>, IPurchaseRepository
    {
        public PurchaseRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<PurchaseList> GetAllPurchase(PurchaseListReq purchaseListReq)
        {
            var param = BuildPurchaseParam(purchaseListReq);

            return DbContext.PurchaseList.FromSqlRaw("[dbo].[Purchase_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@VendorId,@EmpId,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int CountAllPurchase(PurchaseListReq purchaseListReq)
        {
            purchaseListReq.IsCount = true;
            var param = BuildPurchaseParam(purchaseListReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[Purchase_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@VendorId,@EmpId,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[11] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        public void InjectPurchase(PurchaseInjectReq injectReq)
        {
            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var PayeeIdParam = new SqlParameter("@PayeeId", injectReq.PayeeId);

            var PurchaseIdParam = new SqlParameter("@PurchaseId", injectReq.PurchaseId);

            var IsPayNowParam = new SqlParameter("@IsPayNow", injectReq.IsPayNow);

            DbContext.Database.ExecuteSqlRaw("[Purchase_Inject] @EmpId,@PayeeId,@PurchaseId,@IsPayNow", EmpIdParam, PayeeIdParam, PurchaseIdParam, IsPayNowParam);
        }

        public int Checkout(PurchaseCheckoutReq checkoutReq)
        {
            // int parameters
            var PurchaseIdParam = new SqlParameter("@PurchaseId", (object?)checkoutReq.PurchaseId ?? 0);

            var PayeeIdParam = new SqlParameter("@PayeeId", checkoutReq.PayeeId);

            var VendorDocNumberParam = string.IsNullOrWhiteSpace(checkoutReq.VendorDocNumber)
                ? new SqlParameter("@VendorDocNumber", DBNull.Value)
                : new SqlParameter("@VendorDocNumber", checkoutReq.VendorDocNumber);

            var ContainerNumberParam = string.IsNullOrWhiteSpace(checkoutReq.ContainerNumber)
                ? new SqlParameter("@ContainerNumber", DBNull.Value)
                : new SqlParameter("@ContainerNumber", checkoutReq.ContainerNumber);

            // date parameters
            object ToDbDate(DateOnly? d) => d.HasValue ? d.Value.ToDateTime(TimeOnly.MinValue) : DBNull.Value;

            var PurchaseDateParam = checkoutReq.PurchaseDate.HasValue
                ? new SqlParameter("@PurchaseDate", ToDbDate(checkoutReq.PurchaseDate))
                : new SqlParameter("@PurchaseDate", DBNull.Value);

            var ArrivalDateParam = checkoutReq.ArrivalDate.HasValue
                ? new SqlParameter("@ArrivalDate", ToDbDate(checkoutReq.ArrivalDate))
                : new SqlParameter("@ArrivalDate", DBNull.Value);

            var InvoiceDateParam = checkoutReq.InvoiceDate.HasValue
                ? new SqlParameter("@InvoiceDate", ToDbDate(checkoutReq.InvoiceDate))
                : new SqlParameter("@InvoiceDate", DBNull.Value);

            var DueDateParam = checkoutReq.DueDate.HasValue
                ? new SqlParameter("@DueDate", ToDbDate(checkoutReq.DueDate))
                : new SqlParameter("@DueDate", DBNull.Value);

            // notes
            var NotesParam = string.IsNullOrWhiteSpace(checkoutReq.Notes)
                ? new SqlParameter("@Notes", DBNull.Value)
                : new SqlParameter("@Notes", checkoutReq.Notes);

            // stage / pallet / emp
            var StageIdParam = new SqlParameter("@StageId", checkoutReq.StageId);

            var PalletCountParam = checkoutReq.PalletCount.HasValue
                ? new SqlParameter("@PalletCount", checkoutReq.PalletCount)
                : new SqlParameter("@PalletCount", DBNull.Value);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            // output
            var NewPurchaseIdParam = new SqlParameter
            {
                ParameterName = "@NewPurchaseId",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };

            DbContext.Database.ExecuteSqlRaw("[Purchase_Insert] @PurchaseId,@PayeeId,@VendorDocNumber,@ContainerNumber,@PurchaseDate,@ArrivalDate,@InvoiceDate,@DueDate,@Notes,@StageId,@PalletCount,@EmpId,@NewPurchaseId OUTPUT", PurchaseIdParam, PayeeIdParam, VendorDocNumberParam, ContainerNumberParam, PurchaseDateParam, ArrivalDateParam, InvoiceDateParam, DueDateParam, NotesParam, StageIdParam, PalletCountParam, EmpIdParam, NewPurchaseIdParam);

            return (NewPurchaseIdParam.Value == DBNull.Value) ? 0 : Convert.ToInt32(NewPurchaseIdParam.Value);
        }

        private static object[] BuildPurchaseParam(PurchaseListReq purchaseListReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", purchaseListReq.Pageno),

                new SqlParameter("@Pagesize", purchaseListReq.Pagesize),

                string.IsNullOrEmpty(purchaseListReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", purchaseListReq.Search),

                purchaseListReq.StartDate.HasValue ? new SqlParameter("@StartDate", purchaseListReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                purchaseListReq.EndDate.HasValue ? new SqlParameter("@EndDate", purchaseListReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                purchaseListReq.PayeeId.HasValue ? new SqlParameter("@VendorId", purchaseListReq.PayeeId) : new SqlParameter("@VendorId", DBNull.Value),

                new SqlParameter("@EmpId", UserContext.EmpId),

                string.IsNullOrEmpty(purchaseListReq.Filterby) ? new SqlParameter("@Filterby", DBNull.Value) : new SqlParameter("@Filterby", purchaseListReq.Filterby),

                string.IsNullOrEmpty(purchaseListReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", purchaseListReq.SortField),

                string.IsNullOrEmpty(purchaseListReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", purchaseListReq.SortOrder),

                new SqlParameter("@IsCount", purchaseListReq.IsCount),

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
