using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface IVendorService
    {
        IEnumerable<Payee> GetAllVendors();

        Payee? GetById(int payeeId);

        void DeleteVendor(int payeeId);
    }
}
