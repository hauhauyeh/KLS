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
        IEnumerable<Term> GetList();

        IEnumerable<Term> GetActive();

        Term? GetById(int termId);

        bool NameExists(Term term);

        Term Create(Term term);

        Term? Update(Term term);

        void Delete(int termId);

        bool TermUsed(int termId);
    }
}
