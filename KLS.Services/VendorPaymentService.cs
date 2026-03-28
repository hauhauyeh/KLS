using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
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

        public PagingResponse<VendorPaymentList> GetPagedVendorPayments(VendorPaymentReq vendorPaymentReq)
        {
            var list = Uow.VendorPayments.GetPagedVendorPayments(vendorPaymentReq);

            var totalRecords = Uow.VendorPayments.CountVendorPayments(vendorPaymentReq);

            return new PagingResponse<VendorPaymentList>(totalRecords, vendorPaymentReq.Pageno, vendorPaymentReq.Pagesize)
            {
                RowData = list,
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
                    PaymentMethod = EnumHelper.EnumPaymentMethod.ACH.ToString(),
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

            return Uow.VendorPayments.GetPagedVendorPayments(payNowReq).AsEnumerable().FirstOrDefault();
        }

        public VendorPayment? Save(VendorPayment vendorPayment)
        {
            var newPaymentId = Uow.VendorPayments.Save(vendorPayment);

            return GetById(newPaymentId);
        }

        public void Delete(int vendorPaymentId)
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

        public void Return(VendorPaymentReturnReq checkReq)
        {
            Uow.VendorPayments.Return(checkReq);
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

        public VendorPaymentList? SavePayNow(PayNowReq payNowReq)
        {
            var newPaymentId = Uow.VendorPayments.SavePayNow(payNowReq);

            return GetListById(newPaymentId);
        }

        public int ImportPayNow(ImportPayNow importPayNow)
        {
            var txCount = 0;

            if (importPayNow.ExcelFile != null)
            {
                var excelfile = Path.Combine(_hostingEnvironment.WebRootPath, Constants.PayrollPath, importPayNow.ExcelFile.FileName);

                GC.Collect();

                if (File.Exists(excelfile))
                    File.Delete(excelfile);

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


        public void SaveAdvance(VendorPaymentAdvanceReq req)
        {
            Uow.VendorPayments.SaveAdvance(req);
        }

        public IEnumerable<VendorPaymentList>? GetAdvances(int purchaseId)
        {
            return Uow.VendorPayments.GetByPurchaseId(purchaseId);
        }

        public VendorPaymentList? ApplyAdvance(AdvanceApplyReq req)
        {
            Uow.VendorPayments.ApplyAdvanceManual(req);
            return GetListById(req.VendorPaymentId);
        }

        public VendorPaymentList? UnapplyAdvance(int vendorPaymentId)
        {
            Uow.VendorPayments.UnapplyAdvance(vendorPaymentId);
            return GetListById(vendorPaymentId);
        }

        public IEnumerable<VendorAppliedBill>? GetAppliedBills(int vendorPaymentId)
        {
            return Uow.VendorPayments.GetAppliedBills(vendorPaymentId);
        }

        public IEnumerable<VendorPaymentOpenAdvance>? GetOpenAdvances(int payeeId)
        {
            return Uow.VendorPayments.GetOpenAdvances(payeeId);
        }


        public PagingResponse<CheckRegister> GetPagedCheckRegister(CheckRegisterReq checkRegisterReq)
        {
            var list = Uow.VendorPayments.GetPagedCheckRegister(checkRegisterReq);

            var totalRecords = Uow.VendorPayments.CountCheckRegister(checkRegisterReq);

            return new PagingResponse<CheckRegister>(totalRecords, checkRegisterReq.Pageno, checkRegisterReq.Pagesize)
            {
                RowData = list,
            };
        }

        public void UpdateBankDate(CheckRegister checkRegister)
        {
            Uow.VendorPayments.UpdateBankDate(checkRegister);
        }
    }
}
