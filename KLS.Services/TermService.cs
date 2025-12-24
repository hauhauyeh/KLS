using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Data;
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

        public IEnumerable<Term> GetList()
        {
            return Uow.Terms.GetAll().OrderBy(c => c.TermName);
        }

        public IEnumerable<Term> GetActive()
        {
            return Uow.Terms.Find(c => c.Inactive == false).OrderBy(c => c.TermName);
        }

        public Term? GetById(int termId)
        {
            return Uow.Terms.GetById(termId);
        }

        public bool NameExists(Term term)
        {
            return Uow.Terms.Exists(c => c.TermName.ToLower() == term.TermName.ToLower() && c.TermId != term.TermId);
        }

        public bool TermUsed(int termId)
        {
            var term = GetById(termId);
            return Uow.Payees.Exists(c => c.TermId == term.TermId);
        }

        public Term Create(Term term)
        {
            if (NameExists(term))
                throw new DuplicateNameException("Term name already exists.");

            Uow.Terms.Add(term);
            Uow.Commit();

            return term;
        }

        public Term? Update(Term term)
        {
            var existing = GetById(term.TermId);
            if (existing == null) return null;

            if (NameExists(term))
                throw new DuplicateNameException("Term name already exists.");

            // name uniqueness check stays in service
            existing.UpdateTerm(term);

            Uow.Terms.Update(existing);
            Uow.Commit();

            return existing;
        }

        public void Delete(int termId)
        {
            if (TermUsed(termId))
                throw new DuplicateNameException("You can't delete this term because it is assigned to a payee.");

            Uow.Terms.RemoveById(termId);
            Uow.Commit();
        }

        //private static TermDto Map(Term t)
        //    => new(t.TermId, t.TermName, t.TermType, t.DueDays, t.Discount, t.Inactive, t.Notes);
    }
}
