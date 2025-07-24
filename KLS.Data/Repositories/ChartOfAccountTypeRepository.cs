using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Data.Repositories;
using KLS.Models;

namespace KLS.Data.Repositories
{
    public class ChartOfAccountTypeRepository : KLSRepository<ChartOfAccountType>, IChartOfAccountTypeRepository
    {
        public ChartOfAccountTypeRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }
    }
}