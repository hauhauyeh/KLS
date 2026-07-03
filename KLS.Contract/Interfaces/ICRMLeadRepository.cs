using KLS.Models;

namespace KLS.Contract.Interfaces
{
    public interface ICRMLeadRepository : IRepository<CRMLead>
    {
        IQueryable<CRMLeadList> GetPagedList(CRMLeadListReq req);

        int Count(CRMLeadListReq req);

        IQueryable<CRMPipelineSummary> GetPipelineSummary();

        void Convert(int leadId, int payeeId);
    }
}
