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
    public class CompanyRepository : KLSRepository<Company>, ICompanyRepository
    {
        public CompanyRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public DateOnly GetNextWorkDate()
        {
            var NextWorkDateParam = new SqlParameter()
            {
                ParameterName = "@NextWorkDate",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Date
            };

            DbContext.Database.ExecuteSqlRaw("[Get_NextWorkingDate] @NextWorkDate OUTPUT", NextWorkDateParam);

            return DateOnly.FromDateTime((DateTime)NextWorkDateParam.Value);
        }
    }
}
