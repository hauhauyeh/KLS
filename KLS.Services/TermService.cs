using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class TermService : BaseService, ITermService
    {
        public TermService(IUnitOfWork uow) : base(uow)
        {

        }

        public IQueryable<Term> GetAllTerms()
        {
            return Uow.Terms.GetAll().OrderBy(c => c.TermName);
        }

        public ICollection<Term> GetActiveTerms()
        {
            return Uow.Terms.Find(c => c.Inactive == false).OrderBy(c => c.TermName).ToList();
        }

        public Term GetById(int termId)
        {
            return Uow.Terms.GetById(termId);
        }

        public bool ExistsName(Term term)
        {
            return Uow.Terms.Exists(c => c.TermName.ToLower() == term.TermName.ToLower() && c.TermId != term.TermId);
        }

        public bool TermUsed(int termId)
        {
            var term = GetById(termId);
            return Uow.Payees.Exists(c => c.TermId == term.TermId);
        }

        public Term CreateTerm(Term term)
        {
            Uow.Terms.Add(term);
            Uow.Commit();

            return term;
        }

        public Term? UpdateTerm(Term term)
        {
            var existing = GetById(term.TermId);

            if (existing != null)
            {
                existing.TermName = term.TermName;
                existing.TermType = term.TermType;
                existing.DueDays = term.DueDays;
                //existing.DayOfMonth = term.DayOfMonth;
                existing.Discount = term.Discount;
                existing.Inactive = term.Inactive;
                existing.Notes = term.Notes;

                existing.UpdatedAt = DateTime.UtcNow;

                Uow.Terms.Update(existing);
                Uow.Commit();
            }

            return existing;
        }

        public void DeleteTerm(int termId)
        {
            Uow.Terms.RemoveById(termId);
            Uow.Commit();
        }
    }
}
