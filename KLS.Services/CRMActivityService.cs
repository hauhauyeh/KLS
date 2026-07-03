using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;

namespace KLS.Services
{
    public class CRMActivityService : BaseService, ICRMActivityService
    {
        public CRMActivityService(IUnitOfWork uow) : base(uow)
        {
        }

        public ICollection<CRMActivityList> GetByEntity(int? payeeId, int? leadId, int pageNo, int pageSize)
        {
            return Uow.CRMActivities.GetByEntity(payeeId, leadId, pageNo, pageSize).ToList();
        }

        public CRMActivity Create(CRMActivityDTO dto)
        {
            if (dto.PayeeId.HasValue == dto.LeadId.HasValue)
                throw new ArgumentException("An activity must have exactly one parent (customer or lead).");

            CRMActivity activity = null!;

            Uow.ExecuteInTransaction(() =>
            {
                activity = new CRMActivity
                {
                    PayeeId = dto.PayeeId,
                    LeadId = dto.LeadId,
                    ActivityType = dto.ActivityType,
                    Subject = dto.Subject,
                    Description = dto.Description,
                    ActivityDate = dto.ActivityDate ?? DateTime.UtcNow,
                    Duration = dto.Duration,
                    Outcome = dto.Outcome,
                    SalesRepId = UserContext.EmpId,
                    CreatedAt = DateTime.UtcNow,
                    EnterBy = UserContext.EmpId
                };

                Uow.CRMActivities.Add(activity);
                Uow.Commit();

                if (dto.FollowUp != null && dto.FollowUp.DueDate.HasValue)
                {
                    var followUp = new CRMFollowUp
                    {
                        PayeeId = dto.PayeeId,
                        LeadId = dto.LeadId,
                        Subject = dto.FollowUp.Subject ?? $"Follow-up: {dto.Subject}",
                        DueDate = dto.FollowUp.DueDate,
                        Priority = dto.FollowUp.Priority ?? "Medium",
                        Status = "Pending",
                        AssignedTo = UserContext.EmpId,
                        ActivityId = activity.ActivityId,
                        CreatedAt = DateTime.UtcNow,
                        UpdatedAt = DateTime.UtcNow,
                        EnterBy = UserContext.EmpId
                    };

                    Uow.CRMFollowUps.Add(followUp);
                    Uow.Commit();
                }
            });

            return activity;
        }

        public void Delete(int activityId)
        {
            Uow.CRMActivities.RemoveById(activityId);
            Uow.Commit();
        }
    }
}
