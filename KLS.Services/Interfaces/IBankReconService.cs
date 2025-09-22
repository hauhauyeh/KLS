using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface IBankReconService
    {
        //IQueryable<BankRecon> GetAllBankRecon();

        List<BankReconList> GetAllBankRecon();

        BankRecon GetById(int id);

        bool ExistsBankRecon(BankRecon bankRecon);

        BankRecon CreateBankRecon(BankRecon bankRecon);

        BankRecon? UpdateBankRecon(BankRecon bankRecon);

        void UpdateNotes(BankRecon bankRecon);

        void DeleteBankRecon(int bankReconId);
    }
}
