using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;

namespace KLS.Data.Repositories
{
    public class DeliverScheduleRepository : KLSRepository<DeliverSchedule>, IDeliverScheduleRepository
    {
        public DeliverScheduleRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        public DeliverSchedule? GetActiveByPayeeId(int payeeId)
        {
            return DbContext.DeliverSchedules
                .FirstOrDefault(x => x.PayeeId == payeeId && x.IsActive);
        }

        public IQueryable<DeliverSchedule> GetByPayeeId(int payeeId)
        {
            return DbContext.DeliverSchedules.Where(x => x.PayeeId == payeeId);
        }
    }
}
