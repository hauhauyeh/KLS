using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IVendorService
    {
        PagingResponse<VendorList> GetAllVendors(VendorListReq vendorListReq);

        VendorDTO? GetById(int payeeId);

        bool VendorExists(VendorDTO vendorDTO);

        VendorDTO CreateVendor(VendorDTO vendorDTO);

        VendorDTO? UpdateVendor(VendorDTO vendorDTO);

        void DeleteVendor(int payeeId);

        IEnumerable<VendorSearchDTO>? SearchVendor(PayeeSearchReq searchReq);

        IEnumerable<VendorSearchDTO>? GetActiveVendors();
    }
}
