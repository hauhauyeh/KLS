using KLS.Contract.Dtos;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ITermService
    {
        IEnumerable<Term> GetAllTerms();

        IEnumerable<Term> GetActiveTerms();

        Term? GetById(int termId);

        bool ExistsName(Term term);

        Term CreateTerm(Term term);

        Term? UpdateTerm(Term term);

        void DeleteTerm(int termId);

        bool TermUsed(int termId);
    }
}
