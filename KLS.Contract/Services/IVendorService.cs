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
        PagingResponse<VendorList> GetPagedList(VendorListReq vendorListReq);

        VendorDTO? GetById(int payeeId);

        bool VendorExists(VendorDTO vendorDTO);

        VendorDTO Create(VendorDTO vendorDTO);

        VendorDTO? Update(VendorDTO vendorDTO);

        void Delete(int payeeId);

        IEnumerable<VendorSearchDTO>? Search(PayeeSearchReq searchReq);

        IEnumerable<VendorSearchDTO>? GetActive();
    }
}
