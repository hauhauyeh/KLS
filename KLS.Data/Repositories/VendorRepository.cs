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
    public class VendorRepository : KLSRepository<Vendor>, IVendorRepository
    {
        public VendorRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<VendorList> GetPagedList(VendorListReq vendorListReq)
        {
            var param = BuildParam(vendorListReq);

            return DbContext.VendorList.FromSqlRaw("[dbo].[Vendor_GetAllList] @Pageno,@Pagesize,@Search,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int Count(VendorListReq vendorListReq)
        {
            vendorListReq.IsCount = true;
            var param = BuildParam(vendorListReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[Vendor_GetAllList] @Pageno,@Pagesize,@Search,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[6] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        private static object[] BuildParam(VendorListReq vendorListReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", vendorListReq.Pageno),

                new SqlParameter("@Pagesize", vendorListReq.Pagesize),

                string.IsNullOrEmpty(vendorListReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", vendorListReq.Search),

                string.IsNullOrEmpty(vendorListReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", vendorListReq.SortField),

                string.IsNullOrEmpty(vendorListReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", vendorListReq.SortOrder),

                new SqlParameter("@IsCount", vendorListReq.IsCount),

                new SqlParameter()
                {
                    ParameterName = "@TotalCount",
                    Direction = System.Data.ParameterDirection.Output,
                    SqlDbType = System.Data.SqlDbType.Int
                }
            };

            return param;
        }

        public IQueryable<VendorSearchDTO>? Search(PayeeSearchReq searchReq)
        {
            var TermParam = string.IsNullOrEmpty(searchReq.Term) ? new SqlParameter("@SearchTerm", DBNull.Value) : new SqlParameter("@SearchTerm", searchReq.Term);

            var IsActiveOnlyParam = new SqlParameter("@IsActiveOnly", searchReq.IsActiveOnly);

            return DbContext.VendorSearchDTO.FromSqlRaw("[dbo].[Vendor_SearchByTerm] @SearchTerm,@IsActiveOnly", TermParam, IsActiveOnlyParam);
        }

        public IQueryable<PayeeExport> Export()
        {
            return DbContext.PayeeExport.FromSqlRaw("[dbo].[Vendor_Export]");
        }
    }
}