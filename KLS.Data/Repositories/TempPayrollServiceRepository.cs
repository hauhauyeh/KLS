using KLS.Common;
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
    public class TempPayrollServiceRepository : KLSRepository<TempPayrollService>, ITempPayrollServiceRepository
    {
        public TempPayrollServiceRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<TempPurchaseItem>? GetTempPurchaseItems(TempPurchaseReq tempReq)
        {
            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            //var VendorIdParam = new SqlParameter("@VendorId", cartReq.VendorId);

            var PurchaseIdParam = new SqlParameter("@PurchaseId", tempReq.PurchaseId);

            var SortFieldParam = (!string.IsNullOrEmpty(tempReq.SortField)) ? new SqlParameter("@SortField", tempReq.SortField) : new SqlParameter("@SortField", DBNull.Value);

            var SortOrderParam = (!string.IsNullOrEmpty(tempReq.SortOrder)) ? new SqlParameter("@SortOrder", tempReq.SortOrder) : new SqlParameter("@SortOrder", DBNull.Value);

            return DbContext.TempPurchaseItem.FromSqlRaw("[TempPurchase_GetList] @EmpId,@PurchaseId,@SortField,@SortOrder", EmpIdParam, PurchaseIdParam, SortFieldParam, SortOrderParam);
        }
    }
}