using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;

namespace KLS.Data.Repositories
{
    public class SchedulerConfigRepository : KLSRepository<SchedulerConfig>, ISchedulerConfigRepository
    {
        public SchedulerConfigRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }
    }
}
