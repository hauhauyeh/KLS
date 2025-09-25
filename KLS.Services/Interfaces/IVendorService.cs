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

        VendorDTO? GetById(int payeeId);

        bool VendorExists(VendorDTO vendorDTO);

        VendorDTO CreateVendor(VendorDTO vendorDTO);

        VendorDTO? UpdateVendor(VendorDTO vendorDTO);

        void DeleteVendor(int payeeId);

        IEnumerable<PayeeSearch>? SearchVendor(PayeeSearchReq searchReq);
    }
}
