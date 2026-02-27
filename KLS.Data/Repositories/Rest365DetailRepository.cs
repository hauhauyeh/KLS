using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;
using KLS.Models.Reports;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Data.Repositories
{
    public class Rest365DetailRepository : KLSRepository<Rest365Detail>, IRest365DetailRepository
    {
        public Rest365DetailRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }
    }
}
