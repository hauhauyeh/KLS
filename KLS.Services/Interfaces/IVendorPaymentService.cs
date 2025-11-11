using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface IVendorPaymentService
    {
        PagingResponse<CheckRegister> GetCheckRegister(CheckRegisterReq checkRegisterReq);

        PagingResponse<VendorPaymentList> GetVendorPayment(VendorPaymentReq vendorPaymentReq);
        
        void UnVoidCheck(int vendorPaymentId);

        void VendorPaymentReturnCheck(VendorPaymentReturnReq checkReq);

        List<string> GetReturnTypes();
    }
}
