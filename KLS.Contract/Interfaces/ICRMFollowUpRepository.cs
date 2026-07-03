using KLS.Models;

namespace KLS.Contract.Interfaces
{
    public interface ICRMFollowUpRepository : IRepository<CRMFollowUp>
    {
        IQueryable<CRMFollowUpList> GetPagedList(CRMFollowUpListReq req);

        int Count(CRMFollowUpListReq req);

        int GetOverdueCount(int empId);
    }
}
