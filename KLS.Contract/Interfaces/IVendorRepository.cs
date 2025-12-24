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
        IQueryable<VendorList> GetPagedList(VendorListReq vendorListReq);

        int Count(VendorListReq vendorListReq);

        IQueryable<VendorSearchDTO>? Search(PayeeSearchReq searchReq);
    }
}