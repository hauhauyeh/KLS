using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface IBankReconRepository : IRepository<BankRecon>
    {
        BankReconBalance GetBalance(int bankReconId);

        IQueryable<BankTx> GetTx(int bankReconId);

        void UpdateBankDate(BankTx bankTx);
    }
}
