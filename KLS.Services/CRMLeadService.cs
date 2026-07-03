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
            return Uow.CRMLeads.GetById(leadId);
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

            Uow.CRMLeads.Update(existing);
            Uow.Commit();

            return existing;
        }

        public void Delete(int leadId)
        {
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
            if (lead == null)
                throw new KeyNotFoundException("Lead not found.");

            if (lead.ConvertedPayeeId.HasValue && lead.ConvertedPayeeId == payeeId)
                return;

            if (lead.ConvertedPayeeId.HasValue)
                throw new InvalidOperationException("Lead is already converted to a different customer.");

            Uow.CRMLeads.Convert(leadId, payeeId);
        }

        public ICollection<CRMPipelineSummary> GetPipelineSummary()
        {
            return Uow.CRMLeads.GetPipelineSummary().ToList();
        }
    }
}
