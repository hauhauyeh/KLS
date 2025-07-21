using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface ITermService
    {
        IQueryable<Term> GetAllTerms();

        ICollection<Term> GetActiveTerms();

        Term GetById(int id);

        bool ExistsName(Term term);

        Term CreateTerm(Term term);

        Term? UpdateTerm(Term term);

        void DeleteTerm(int termid);

        bool TermUsed(int termid);
    }
}
