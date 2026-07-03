using KLS.Models;

namespace KLS.Contract.Services
{
    public interface ICRMActivityService
    {
        ICollection<CRMActivityList> GetByEntity(int? payeeId, int? leadId, int pageNo, int pageSize);

        CRMActivity Create(CRMActivityDTO dto);

        void Delete(int activityId);
    }
}
