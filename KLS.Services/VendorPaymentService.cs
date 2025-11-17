using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
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
        private readonly ISystemSettingService _systemSettingService;

        public VendorPaymentService(IUnitOfWork uow, ISystemSettingService systemSettingService) : base(uow)
        {
            _systemSettingService = systemSettingService;
        }

        public PagingResponse<VendorPaymentList> GetAllVendorPayments(VendorPaymentReq vendorPaymentReq)
        {
            var vendorPaymentlist = Uow.VendorPayments.GetAllVendorPayments(vendorPaymentReq);

            var totalRecords = Uow.VendorPayments.CountAllVendorPayments(vendorPaymentReq);

            return new PagingResponse<VendorPaymentList>(totalRecords, vendorPaymentReq.Pageno, vendorPaymentReq.Pagesize)
            {
                RowData = vendorPaymentlist,
            };
        }

        public VendorPayment GetById(int vendorPaymentId)
        {
            if (vendorPaymentId > 0)
                return Uow.VendorPayments.GetById(vendorPaymentId);
            else
                return new VendorPayment
                {
                    PaymentDate = DateOnly.FromDateTime(DateTime.Now),
                    PaymentMethod = EnumHelper.PaymentMethod.ACH.ToString(),
                    FromAccountId = _systemSettingService.GetByKey<int>(GlobalKey.PAYMENT_DEFAULT_BANK),
                    PaymentType = "Bill Payment"
                };
        }

        public VendorPaymentList? GetListById(int vendorPaymentId)
        {
            var payNowReq = new VendorPaymentReq
            {
                Id = vendorPaymentId
            };

            return Uow.VendorPayments.GetAllVendorPayments(payNowReq).AsEnumerable().FirstOrDefault();
        }

        public void DeleteVendorPayment(int vendorPaymentId)
        {
            var payment = GetById(vendorPaymentId);

            if (payment != null && !payment.IsLocked)
            {
                Uow.VendorPayments.Find(c => c.VendorPaymentId == vendorPaymentId).ExecuteDelete();
            }
        }

        public void VoidCheck(int vendorPaymentId)
        {
            Uow.VendorPayments.VoidCheck(vendorPaymentId);
        }

        public void UnVoidCheck(int vendorPaymentId)
        {
            Uow.VendorPayments.UnVoidCheck(vendorPaymentId);
        }

        public void VendorPaymentReturn(VendorPaymentReturnReq checkReq)
        {
            Uow.VendorPayments.VendorPaymentReturn(checkReq);
        }

        public void DeleteReturn(int vendorPaymentId)
        {
            Uow.VendorPayments.DeleteReturn(vendorPaymentId);
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

        public VendorPaymentList? SavePayNowPayment(PayNowReq payNowReq)
        {
            var newPaymentId = Uow.VendorPayments.SavePayNowPayment(payNowReq);

            return GetListById(newPaymentId);
        }


        public PagingResponse<CheckRegister> GetAllCheckRegister(CheckRegisterReq checkRegisterReq)
        {
            var registerlist = Uow.VendorPayments.GetAllCheckRegister(checkRegisterReq);

            var totalRecords = Uow.VendorPayments.CountAllCheckRegister(checkRegisterReq);

            return new PagingResponse<CheckRegister>(totalRecords, checkRegisterReq.Pageno, checkRegisterReq.Pagesize)
            {
                RowData = registerlist,
            };
        }
    }
}
