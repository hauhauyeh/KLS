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
            return Uow.Terms.Find(c => c.IsInactive == false).OrderBy(c => c.TermName).ToList();
        }

        public Term GetById(int id)
        {
            return Uow.Terms.GetById(id);
        }

        public bool ExistsName(Term term)
        {
            return Uow.Terms.Exists(c => c.TermName.ToLower() == term.TermName.ToLower() && c.TermId != term.TermId);
        }

        public bool TermUsed(int termid)
        {
            var term = GetById(termid);
            return Uow.Payees.Exists(c => c.TermName == term.TermName);
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
                existing.IsInactive = term.IsInactive;
                existing.Notes = term.Notes;

                existing.UpdatedAt = DateTime.UtcNow;

                Uow.Terms.Update(existing);
                Uow.Commit();
            }

            return existing;
        }

        public void DeleteTerm(int termid)
        {
            Uow.Terms.RemoveById(termid);
            Uow.Commit();
        }
    }
}
