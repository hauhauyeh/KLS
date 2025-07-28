using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;

namespace KLS.Data.Repositories
{
    public class ChartOfAccountRepository : KLSRepository<ChartOfAccount>, IChartOfAccountRepository
    {
        public ChartOfAccountRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }
    }
}