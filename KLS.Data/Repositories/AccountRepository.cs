using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace KLS.Data.Repositories
{
    public class AccountRepository : KLSRepository<Account>, IAccountRepository
    {
        public AccountRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<AccountDTO> SearchAccount(string term)
        {
            var TermParam = (!string.IsNullOrEmpty(term)) ? new SqlParameter("@SearchTerm", term) : new SqlParameter("@SearchTerm", DBNull.Value);

            return DbContext.AccountDTO.FromSqlRaw("[Account_SearchbyTerm] @SearchTerm", TermParam);
        }

        public CreditDebitAmount GetCrDeAmount(string accountCode, decimal? amount)
        {
            var AcctCodeParam = new SqlParameter("@AccountCode", accountCode);

            var AmountParam = new SqlParameter("@Amount", amount);

            return DbContext.CreditDebitAmount.FromSqlRaw("[Get_CreditDebitAmount] @AccountCode,@Amount", AcctCodeParam, AmountParam).AsEnumerable().FirstOrDefault();
        }
    }
}