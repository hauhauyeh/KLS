using KLS.Models;

namespace KLS.Contract.Services
{
    public interface ICRMFollowUpService
    {
        PagingResponse<CRMFollowUpList> GetPagedList(CRMFollowUpListReq req);

        ICollection<CRMFollowUpList> GetByEntity(int? payeeId, int? leadId, int pageNo, int pageSize);

        CRMFollowUp? GetById(int followUpId);

        CRMFollowUp Create(CRMFollowUpDTO dto);

        CRMFollowUp? Update(CRMFollowUpDTO dto);

        CRMFollowUpCompleteResult CompleteWithActivity(int followUpId, CRMFollowUpCompleteReq req);

        void Delete(int followUpId);

        int GetOverdueCount();

        ICollection<CRMMyDayItem> GetMyDay();
    }
}
