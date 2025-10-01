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

        public IQueryable<VendorSearchDTO>? SearchVendor(PayeeSearchReq searchReq)
        {
            var TermParam = string.IsNullOrEmpty(searchReq.Term) ? new SqlParameter("@SearchTerm", DBNull.Value) : new SqlParameter("@SearchTerm", searchReq.Term);

            var IsActiveParam = new SqlParameter("@IsActive", searchReq.IsActiveOnly);

            return DbContext.VendorSearchDTO.FromSqlRaw("[dbo].[Vendor_SearchbyTerm] @SearchTerm,@IsActive", TermParam, IsActiveParam);
        }
    }
}