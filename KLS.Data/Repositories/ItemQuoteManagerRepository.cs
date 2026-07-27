using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace KLS.Data.Repositories
{
    public class ItemQuoteManagerRepository : IItemQuoteManagerRepository
    {
        private readonly KLSDBContext _dbContext;

        public ItemQuoteManagerRepository(KLSDBContext dbContext)
        {
            _dbContext = dbContext;
        }

        public IQueryable<ItemQuoteManagerRow> GetRows(int payeeId)
        {
            var empIdParam = new SqlParameter("@EmpId", UserContext.EmpId);
            var payeeIdParam = new SqlParameter("@PayeeId", payeeId);

            return _dbContext.ItemQuoteManagerRows
                .FromSqlRaw("[ItemQuoteManager_GetList] @EmpId,@PayeeId", empIdParam, payeeIdParam);
        }
    }
}
