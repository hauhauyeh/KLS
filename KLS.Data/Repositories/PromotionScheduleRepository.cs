using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Data.DataContext;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Data.Repositories
{
    public class PromotionScheduleRepository : KLSRepository<PromotionSchedule>, IPromotionScheduleRepository
    {
        public PromotionScheduleRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }
    }
}
