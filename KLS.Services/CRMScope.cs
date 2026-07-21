using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;

namespace KLS.Services
{
    // CRM row-level visibility (plan-crm-phase-0). Backend owns the rule;
    // out-of-scope ids surface as 404 via KeyNotFoundException, matching
    // row invisibility. Admin (non-sales role) passes every check.
    internal static class CRMScope
    {
        public static void EnsureLead(IUnitOfWork uow, CRMLead? lead)
        {
            if (lead == null)
                throw new KeyNotFoundException("Lead not found.");

            if (!UserContext.IsSalesRole)
                return;

            if (lead.SalesRepId == UserContext.EmpId)
                return;

            // Converted lead: history follows the customer owner.
            if (lead.ConvertedPayeeId.HasValue &&
                uow.Customers.Exists(c => c.PayeeId == lead.ConvertedPayeeId.Value && c.SalesRepId == UserContext.EmpId))
                return;

            throw new KeyNotFoundException("Lead not found.");
        }

        public static void EnsurePayee(IUnitOfWork uow, int payeeId)
        {
            if (!UserContext.IsSalesRole)
                return;

            if (uow.Customers.Exists(c => c.PayeeId == payeeId && c.SalesRepId == UserContext.EmpId))
                return;

            throw new KeyNotFoundException("Customer not found.");
        }

        public static void EnsureEntity(IUnitOfWork uow, int? payeeId, int? leadId)
        {
            if (!UserContext.IsSalesRole)
                return;

            if (leadId.HasValue)
                EnsureLead(uow, uow.CRMLeads.GetById(leadId.Value));
            else if (payeeId.HasValue)
                EnsurePayee(uow, payeeId.Value);
        }

        // A follow-up is accessible to its assignee or to anyone who can see its parent.
        public static void EnsureFollowUp(IUnitOfWork uow, CRMFollowUp? followUp)
        {
            if (followUp == null)
                throw new KeyNotFoundException("Follow-up not found.");

            if (!UserContext.IsSalesRole)
                return;

            if (followUp.AssignedTo == UserContext.EmpId)
                return;

            EnsureEntity(uow, followUp.PayeeId, followUp.LeadId);
        }
    }
}
