using KLS.Models;

namespace KLS.Contract.Services
{
    public interface ICRMFollowUpService
    {
        PagingResponse<CRMFollowUpList> GetPagedList(CRMFollowUpListReq req);

        CRMFollowUp? GetById(int followUpId);

        CRMFollowUp Create(CRMFollowUpDTO dto);

        CRMFollowUp? Update(CRMFollowUpDTO dto);

        void Complete(int followUpId, int? activityId);

        void Delete(int followUpId);

        int GetOverdueCount();
    }
}
