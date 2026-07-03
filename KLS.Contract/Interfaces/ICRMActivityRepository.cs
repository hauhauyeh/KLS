using KLS.Models;

namespace KLS.Contract.Interfaces
{
    public interface ICRMActivityRepository : IRepository<CRMActivity>
    {
        IQueryable<CRMActivityList> GetByEntity(int? payeeId, int? leadId, int pageNo, int pageSize);
    }
}
