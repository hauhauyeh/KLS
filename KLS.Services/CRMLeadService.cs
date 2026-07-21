using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;

namespace KLS.Services
{
    public class CRMLeadService : BaseService, ICRMLeadService
    {
        public CRMLeadService(IUnitOfWork uow) : base(uow)
        {
        }

        public PagingResponse<CRMLeadList> GetPagedList(CRMLeadListReq req)
        {
            var list = Uow.CRMLeads.GetPagedList(req);
            var totalRecords = Uow.CRMLeads.Count(req);

            return new PagingResponse<CRMLeadList>(totalRecords, req.Pageno, req.Pagesize)
            {
                RowData = list
            };
        }

        public CRMLead? GetById(int leadId)
        {
            var lead = Uow.CRMLeads.GetById(leadId);
            if (lead == null) return null;

            CRMScope.EnsureLead(Uow, lead);
            return lead;
        }

        public CRMLead Create(CRMLeadDTO dto)
        {
            var lead = new CRMLead
            {
                LeadName = dto.LeadName,
                ContactPerson = dto.ContactPerson,
                Phone = dto.Phone,
                Email = dto.Email,
                Address = dto.Address,
                City = dto.City,
                State = dto.State,
                ZipCode = dto.ZipCode,
                Source = dto.Source,
                Stage = dto.Stage ?? "New",
                SalesRepId = dto.SalesRepId ?? UserContext.EmpId,
                Notes = dto.Notes,
                EstimatedValue = dto.EstimatedValue,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                EnterBy = UserContext.EmpId
            };

            Uow.CRMLeads.Add(lead);
            Uow.Commit();

            return lead;
        }

        public CRMLead? Update(CRMLeadDTO dto)
        {
            var existing = Uow.CRMLeads.GetById(dto.LeadId);
            if (existing == null) return null;

            CRMScope.EnsureLead(Uow, existing);

            var oldStage = existing.Stage;

            existing.LeadName = dto.LeadName;
            existing.ContactPerson = dto.ContactPerson;
            existing.Phone = dto.Phone;
            existing.Email = dto.Email;
            existing.Address = dto.Address;
            existing.City = dto.City;
            existing.State = dto.State;
            existing.ZipCode = dto.ZipCode;
            existing.Source = dto.Source;
            existing.Stage = dto.Stage;
            existing.SalesRepId = dto.SalesRepId;
            existing.Notes = dto.Notes;
            existing.EstimatedValue = dto.EstimatedValue;
            existing.LostReason = dto.LostReason;
            existing.UpdatedAt = DateTime.UtcNow;
            existing.UpdateBy = UserContext.EmpId;

            Uow.ExecuteInTransaction(() =>
            {
                Uow.CRMLeads.Update(existing);
                Uow.Commit();

                if (!string.IsNullOrEmpty(dto.Stage) && dto.Stage != oldStage)
                    AddSystemActivity(existing.LeadId, "Stage changed", $"{oldStage} -> {dto.Stage}");
            });

            return existing;
        }

        public void Delete(int leadId)
        {
            var lead = Uow.CRMLeads.GetById(leadId);
            if (lead == null) return;

            CRMScope.EnsureLead(Uow, lead);

            if (Uow.CRMActivities.Exists(a => a.LeadId == leadId))
                throw new InvalidOperationException("Cannot delete lead with existing activities. Set stage to Lost instead.");

            if (Uow.CRMFollowUps.Exists(f => f.LeadId == leadId))
                throw new InvalidOperationException("Cannot delete lead with existing follow-ups. Set stage to Lost instead.");

            Uow.CRMLeads.RemoveById(leadId);
            Uow.Commit();
        }

        public void Convert(int leadId, int payeeId)
        {
            var lead = Uow.CRMLeads.GetById(leadId);
            CRMScope.EnsureLead(Uow, lead);

            if (lead!.ConvertedPayeeId.HasValue && lead.ConvertedPayeeId == payeeId)
                return;

            if (lead.ConvertedPayeeId.HasValue)
                throw new InvalidOperationException("Lead is already converted to a different customer.");

            if (!Uow.Payees.Exists(p => p.PayeeId == payeeId))
                throw new KeyNotFoundException("Target customer not found.");

            Uow.ExecuteInTransaction(() =>
            {
                Uow.CRMLeads.Convert(leadId, payeeId);
                AddSystemActivity(leadId, "Lead converted to customer", $"Created customer/payee #{payeeId}");
            });
        }

        private void AddSystemActivity(int leadId, string subject, string description)
        {
            Uow.CRMActivities.Add(new CRMActivity
            {
                LeadId = leadId,
                ActivityType = "System",
                Subject = subject,
                Description = description,
                ActivityDate = DateTime.UtcNow,
                SalesRepId = UserContext.EmpId,
                CreatedAt = DateTime.UtcNow,
                EnterBy = UserContext.EmpId
            });
            Uow.Commit();
        }

        public ICollection<CRMPipelineSummary> GetPipelineSummary()
        {
            return Uow.CRMLeads.GetPipelineSummary().ToList();
        }
    }
}
