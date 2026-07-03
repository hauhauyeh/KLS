using KLS.Models;

namespace KLS.Contract.Services
{
    public interface ICRMLeadService
    {
        PagingResponse<CRMLeadList> GetPagedList(CRMLeadListReq req);

        CRMLead? GetById(int leadId);

        CRMLead Create(CRMLeadDTO dto);

        CRMLead? Update(CRMLeadDTO dto);

        void Delete(int leadId);

        void Convert(int leadId, int payeeId);

        ICollection<CRMPipelineSummary> GetPipelineSummary();
    }
}
