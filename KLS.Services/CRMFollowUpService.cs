using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;

namespace KLS.Services
{
    public class CRMFollowUpService : BaseService, ICRMFollowUpService
    {
        public CRMFollowUpService(IUnitOfWork uow) : base(uow)
        {
        }

        public PagingResponse<CRMFollowUpList> GetPagedList(CRMFollowUpListReq req)
        {
            var list = Uow.CRMFollowUps.GetPagedList(req);
            var totalRecords = Uow.CRMFollowUps.Count(req);

            return new PagingResponse<CRMFollowUpList>(totalRecords, req.Pageno, req.Pagesize)
            {
                RowData = list
            };
        }

        public ICollection<CRMFollowUpList> GetByEntity(int? payeeId, int? leadId, int pageNo, int pageSize)
        {
            if (payeeId.HasValue == leadId.HasValue)
                throw new ArgumentException("Provide exactly one of payeeId or leadId.");

            return Uow.CRMFollowUps.GetByEntity(payeeId, leadId, pageNo, pageSize).ToList();
        }

        public CRMFollowUp? GetById(int followUpId)
        {
            return Uow.CRMFollowUps.GetById(followUpId);
        }

        public CRMFollowUp Create(CRMFollowUpDTO dto)
        {
            if (dto.PayeeId.HasValue == dto.LeadId.HasValue)
                throw new ArgumentException("A follow-up must have exactly one parent (customer or lead).");

            var followUp = new CRMFollowUp
            {
                PayeeId = dto.PayeeId,
                LeadId = dto.LeadId,
                Subject = dto.Subject,
                Description = dto.Description,
                DueDate = dto.DueDate,
                DueTime = dto.DueTime,
                Priority = dto.Priority ?? "Medium",
                Status = "Pending",
                AssignedTo = dto.AssignedTo ?? UserContext.EmpId,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                EnterBy = UserContext.EmpId
            };

            Uow.CRMFollowUps.Add(followUp);
            Uow.Commit();

            return followUp;
        }

        public CRMFollowUp? Update(CRMFollowUpDTO dto)
        {
            var existing = Uow.CRMFollowUps.GetById(dto.FollowUpId);
            if (existing == null) return null;

            existing.Subject = dto.Subject;
            existing.Description = dto.Description;
            existing.DueDate = dto.DueDate;
            existing.DueTime = dto.DueTime;
            existing.Priority = dto.Priority;
            existing.AssignedTo = dto.AssignedTo;
            existing.UpdatedAt = DateTime.UtcNow;
            existing.UpdateBy = UserContext.EmpId;

            Uow.CRMFollowUps.Update(existing);
            Uow.Commit();

            return existing;
        }

        public void Complete(int followUpId, int? activityId)
        {
            var existing = Uow.CRMFollowUps.GetById(followUpId);
            if (existing == null)
                throw new KeyNotFoundException("Follow-up not found.");

            existing.Status = "Completed";
            existing.CompletedAt = DateTime.UtcNow;
            existing.CompletedBy = UserContext.EmpId;
            existing.ActivityId = activityId;
            existing.UpdatedAt = DateTime.UtcNow;
            existing.UpdateBy = UserContext.EmpId;

            Uow.CRMFollowUps.Update(existing);
            Uow.Commit();
        }

        public void Delete(int followUpId)
        {
            Uow.CRMFollowUps.RemoveById(followUpId);
            Uow.Commit();
        }

        public int GetOverdueCount()
        {
            return Uow.CRMFollowUps.GetOverdueCount(UserContext.EmpId);
        }
    }
}
