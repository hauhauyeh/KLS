using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Hosting;
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
        private readonly IDeleteLogService _deleteLogService;
        private IWebHostEnvironment _hostingEnvironment;

        public VendorPaymentService(IUnitOfWork uow, ISystemSettingService systemSettingService, IDeleteLogService deleteLogService, IWebHostEnvironment hostingEnvironment) : base(uow)
        {
            _systemSettingService = systemSettingService;
            _deleteLogService = deleteLogService;
            _hostingEnvironment = hostingEnvironment;
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

        public VendorPayment? SaveVendorPayment(VendorPayment vendorPayment)
        {
            var newPaymentId = Uow.VendorPayments.SaveVendorPayment(vendorPayment);

            return GetById(newPaymentId);
        }

        public void DeleteVendorPayment(int vendorPaymentId)
        {
            var payment = GetById(vendorPaymentId);

            if (payment != null && !payment.IsLocked)
            {
                Uow.VendorPayments.Find(c => c.VendorPaymentId == vendorPaymentId).ExecuteDelete();

                string docType = payment.PaymentType.ToString();

                _deleteLogService.Add(docType, vendorPaymentId);
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

        public int ImportPayNow(ImportPayNow importPayNow)
        {
            var txCount = 0;

            if (importPayNow.ExcelFile != null)
            {
                var excelfile = Path.Combine(_hostingEnvironment.WebRootPath, Constants.PayrollPath, importPayNow.ExcelFile.FileName);

                GC.Collect();

                if (System.IO.File.Exists(excelfile))
                    System.IO.File.Delete(excelfile);

                using (var fileStream = new FileStream(excelfile, FileMode.Create))
                {
                    importPayNow.ExcelFile.CopyTo(fileStream);
                }

                GC.Collect();

                importPayNow.FilePath = excelfile;

                txCount = Uow.VendorPayments.ImportPayNow(importPayNow);
            }

            return txCount;
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
