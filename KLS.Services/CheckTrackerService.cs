using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class CheckTrackerService : BaseService, ICheckTrackerService
    {
        public CheckTrackerService(IUnitOfWork uow) : base(uow)
        {
        }

        public string GetCheckNumber(int accountId)
        {
            // Get max check number for this account
            int? max = Uow.CheckTrackers
                .Find(x => x.AccountId == accountId && x.CheckNumber != null)
                .Max(x => (int?)x.CheckNumber);

            int nextCheckNumber = (max ?? 0) + 1;

            // Return as 5-digit string
            return nextCheckNumber.ToString("D5");
        }
    }
}
