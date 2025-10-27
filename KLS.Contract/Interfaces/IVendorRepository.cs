using KLS.Contract.Interfaces;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface IVendorRepository : IRepository<Vendor>
    {
        IQueryable<VendorList> GetVendors(VendorListReq vendorListReq);

        int CountAllVendors(VendorListReq vendorListReq);

        IQueryable<VendorSearchDTO>? SearchVendor(PayeeSearchReq searchReq);
    }
}