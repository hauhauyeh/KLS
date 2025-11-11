using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class VendorPaymentService : BaseService, IVendorPaymentService
    {
        public VendorPaymentService(IUnitOfWork uow) : base(uow)
        {

        }

        public PagingResponse<CheckRegister> GetCheckRegister(CheckRegisterReq checkRegisterReq)
        {
            var registerlist = Uow.VendorPayments.GetCheckRegister(checkRegisterReq);

            var totalRecords = Uow.VendorPayments.GetCheckRegister(checkRegisterReq).ToList().Count();

            return new PagingResponse<CheckRegister>(totalRecords, checkRegisterReq.Pageno, checkRegisterReq.Pagesize)
            {
                RowData = registerlist,
            };
        }

        public PagingResponse<VendorPaymentList> GetVendorPayment(VendorPaymentReq vendorPaymentReq)
        {
            var vendorPaymentlist = Uow.VendorPayments.GetVendorPayment(vendorPaymentReq);

            var totalRecords = Uow.VendorPayments.CountAllVendorPayment(vendorPaymentReq);

            return new PagingResponse<VendorPaymentList>(totalRecords, vendorPaymentReq.Pageno, vendorPaymentReq.Pagesize)
            {
                RowData = vendorPaymentlist,
            };
        }

        public void UnVoidCheck(int vendorPaymentId)
        {
            Uow.VendorPayments.UnVoidCheck(vendorPaymentId);
        }

        public void VendorPaymentReturnCheck(VendorPaymentReturnReq checkReq)
        {
            Uow.VendorPayments.VendorPaymentReturnCheck(checkReq);
        }

        public List<string> GetReturnTypes()
        {
            var types = new List<string>();

            foreach (var enumValue in Enum.GetValues<EnumHelper.ReturnTypes>())
            {
                var field = enumValue.GetType().GetField(enumValue.ToString());

                if (Attribute.GetCustomAttribute(field, typeof(DisplayAttribute)) is DisplayAttribute attribute)
                {
                    types.Add(attribute.Name);
                }
            }

            return types;
        }
    }
}
