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
        List<BankReconList> GetList();

        BankRecon GetById(int bankReconId);

        bool Exists(BankRecon bankRecon);

        BankRecon Create(BankRecon bankRecon);

        BankRecon? Update(BankRecon bankRecon);

        void UpdateNotes(BankRecon bankRecon);

        void Delete(int bankReconId);
    }
}
