using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;

namespace KLS.Data.Repositories
{
    public class LabelPrintLogRepository : KLSRepository<LabelPrintLog>, ILabelPrintLogRepository
    {
        public LabelPrintLogRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }
    }
}
