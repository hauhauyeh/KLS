using KLS.Models;

namespace KLS.Contract.Interfaces
{
    public interface ICRMFollowUpRepository : IRepository<CRMFollowUp>
    {
        IQueryable<CRMFollowUpList> GetPagedList(CRMFollowUpListReq req);

        IQueryable<CRMFollowUpList> GetByEntity(int? payeeId, int? leadId, int pageNo, int pageSize);

        int Count(CRMFollowUpListReq req);

        int GetOverdueCount(int empId);

        IQueryable<CRMMyDayItem> GetMyDay(int empId, DateOnly today, DateTime todayStartUtc, DateTime todayEndUtc);
    }
}
