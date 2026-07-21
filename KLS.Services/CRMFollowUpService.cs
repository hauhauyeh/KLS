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

            CRMScope.EnsureEntity(Uow, payeeId, leadId);

            return Uow.CRMFollowUps.GetByEntity(payeeId, leadId, pageNo, pageSize).ToList();
        }

        public CRMFollowUp? GetById(int followUpId)
        {
            var followUp = Uow.CRMFollowUps.GetById(followUpId);
            if (followUp == null) return null;

            CRMScope.EnsureFollowUp(Uow, followUp);
            return followUp;
        }

        public CRMFollowUp Create(CRMFollowUpDTO dto)
        {
            if (dto.PayeeId.HasValue == dto.LeadId.HasValue)
                throw new ArgumentException("A follow-up must have exactly one parent (customer or lead).");

            CRMScope.EnsureEntity(Uow, dto.PayeeId, dto.LeadId);

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

            CRMScope.EnsureFollowUp(Uow, existing);

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

        public CRMFollowUpCompleteResult CompleteWithActivity(int followUpId, CRMFollowUpCompleteReq req)
        {
            if (string.IsNullOrWhiteSpace(req.ActivityType))
                throw new ArgumentException("Activity type is required.");

            if (string.IsNullOrWhiteSpace(req.Subject))
                throw new ArgumentException("Subject is required.");

            var existing = Uow.CRMFollowUps.GetById(followUpId);
            CRMScope.EnsureFollowUp(Uow, existing);

            if (existing!.Status != "Pending")
                throw new InvalidOperationException("Only pending follow-ups can be completed.");

            var result = new CRMFollowUpCompleteResult();

            Uow.ExecuteInTransaction(() =>
            {
                var activity = new CRMActivity
                {
                    PayeeId = existing.PayeeId,
                    LeadId = existing.LeadId,
                    ActivityType = req.ActivityType,
                    Subject = req.Subject,
                    Description = req.Description,
                    ActivityDate = req.ActivityDate ?? DateTime.UtcNow,
                    Duration = req.Duration,
                    Outcome = req.Outcome,
                    SalesRepId = UserContext.EmpId,
                    CreatedAt = DateTime.UtcNow,
                    EnterBy = UserContext.EmpId
                };

                Uow.CRMActivities.Add(activity);
                Uow.Commit();

                existing.Status = "Completed";
                existing.CompletedAt = DateTime.UtcNow;
                existing.CompletedBy = UserContext.EmpId;
                existing.CompletedActivityId = activity.ActivityId;
                existing.UpdatedAt = DateTime.UtcNow;
                existing.UpdateBy = UserContext.EmpId;

                Uow.CRMFollowUps.Update(existing);
                Uow.Commit();

                result.Activity = activity;
                result.FollowUp = existing;

                if (req.Next != null && req.Next.DueDate.HasValue)
                {
                    var next = new CRMFollowUp
                    {
                        PayeeId = existing.PayeeId,
                        LeadId = existing.LeadId,
                        Subject = req.Next.Subject ?? existing.Subject,
                        Description = req.Next.Description,
                        DueDate = req.Next.DueDate,
                        DueTime = req.Next.DueTime,
                        Priority = req.Next.Priority ?? "Medium",
                        Status = "Pending",
                        AssignedTo = req.Next.AssignedTo ?? UserContext.EmpId,
                        CreatedFromActivityId = activity.ActivityId,
                        CreatedAt = DateTime.UtcNow,
                        UpdatedAt = DateTime.UtcNow,
                        EnterBy = UserContext.EmpId
                    };

                    Uow.CRMFollowUps.Add(next);
                    Uow.Commit();

                    result.NextFollowUp = next;
                }
            });

            return result;
        }

        public void Delete(int followUpId)
        {
            var existing = Uow.CRMFollowUps.GetById(followUpId);
            CRMScope.EnsureFollowUp(Uow, existing);

            Uow.CRMFollowUps.RemoveById(followUpId);
            Uow.Commit();
        }

        public int GetOverdueCount()
        {
            return Uow.CRMFollowUps.GetOverdueCount(UserContext.EmpId);
        }

        // "Today" is the user's local day (JWT timezone claim); CompletedAt is
        // stored UTC, so the SP gets the local day as an explicit UTC window.
        public ICollection<CRMMyDayItem> GetMyDay()
        {
            TimeZoneInfo tz;
            try
            {
                tz = TimeZoneInfo.FindSystemTimeZoneById(UserContext.UserTimezone ?? "UTC");
            }
            catch
            {
                tz = TimeZoneInfo.Utc;
            }

            var localNow = TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, tz);
            var today = DateOnly.FromDateTime(localNow);
            var todayStartUtc = TimeZoneInfo.ConvertTimeToUtc(localNow.Date, tz);
            var todayEndUtc = todayStartUtc.AddDays(1);

            return Uow.CRMFollowUps.GetMyDay(UserContext.EmpId, today, todayStartUtc, todayEndUtc).ToList();
        }
    }
}
