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
    public class PayeeRepository : KLSRepository<Payee>, IPayeeRepository
    {
        public PayeeRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        public IQueryable<PayeeSearch>? SearchPayee(PayeeSearchReq searchReq)
        {
            var TermParam = string.IsNullOrEmpty(searchReq.Term) ? new SqlParameter("@SearchTerm", DBNull.Value) : new SqlParameter("@SearchTerm", searchReq.Term);

            var IsActiveOnlyParam = new SqlParameter("@IsActiveOnly", searchReq.IsActiveOnly);

            return DbContext.PayeeSearch.FromSqlRaw("[dbo].[Payee_SearchByTerm] @SearchTerm,@IsActiveOnly", TermParam, IsActiveOnlyParam);
        }
    }
}
