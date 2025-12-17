using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IBankReconService
    {
        List<BankReconList> GetAllBankRecon();

        BankRecon GetById(int bankReconId);

        bool ExistsBankRecon(BankRecon bankRecon);

        BankRecon CreateBankRecon(BankRecon bankRecon);

        BankRecon? UpdateBankRecon(BankRecon bankRecon);

        void UpdateNotes(BankRecon bankRecon);

        void DeleteBankRecon(int bankReconId);
    }
}
