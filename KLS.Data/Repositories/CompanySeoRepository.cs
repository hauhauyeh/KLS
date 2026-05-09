using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;

namespace KLS.Data.Repositories
{
    public class CompanySeoRepository : KLSRepository<CompanySeo>, ICompanySeoRepository
    {
        public CompanySeoRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }
    }
}
