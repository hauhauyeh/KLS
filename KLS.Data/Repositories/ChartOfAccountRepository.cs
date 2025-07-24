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

        public ICollection<ChartAccountList> GetAllChartOfAccounts(PagingRequest req)
        {
            var acctcategory = (from at in DbContext.ChartOfAccountTypes
                                select new { at.CatNumber, at.CatName }).Distinct()
                               .OrderBy(x => x.CatNumber).ToList();

            var accts = new List<ChartAccountList>();

            if (!string.IsNullOrEmpty(req.Content))
                acctcategory = acctcategory.Where(c => c.CatName.ToLower() == req.Content).ToList();

            //foreach (var cat in acctcategory)
            //{
            //    var lst = from a in DbContext.ChartOfAccounts
            //              join at in DbContext.ChartOfAccountTypes on a.AccountTypeId equals at.AccountType
            //              where at.CatName == cat.CatName
            //              select new AcctList
            //              {
            //                  AcctId = a.AccountId,
            //                  AcctType = a.AccountType,
            //                  AcctCode = a.ChartAcctCode,
            //                  AcctName = a.ChartAcctName,
            //                  AcctBalance = a.ChartAcctBalance
            //              };

            //    if (!string.IsNullOrEmpty(req.Search))
            //    {
            //        lst = lst.Where(c => c.AcctName.Contains(req.Search) || c.AcctCode.Contains(req.Search));
            //    }

            //    accts.Add(new ChartAccountList { AcctCategory = cat.CatName, Accounts = lst });
            //}

            return accts.Where(c => c.Accounts.Count() > 0).ToList();
        }
    }
}