using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Data.Repositories
{
    public class TempTimesheetRepository : KLSRepository<TempTimesheet>, ITempTimesheetRepository
    {
        public TempTimesheetRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }
    }
}