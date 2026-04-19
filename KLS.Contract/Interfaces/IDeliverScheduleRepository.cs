using KLS.Models;

namespace KLS.Contract.Interfaces
{
    public interface IDeliverScheduleRepository : IRepository<DeliverSchedule>
    {
        DeliverSchedule? GetActiveByPayeeId(int payeeId);

        IQueryable<DeliverSchedule> GetByPayeeId(int payeeId);
    }
}
