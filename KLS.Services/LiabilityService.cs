using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Hosting;
using Omu.ValueInjecter;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class LiabilityService : BaseService, ILiabilityService
    {
        private readonly IWebHostEnvironment _env;

        public LiabilityService(IUnitOfWork uow, IWebHostEnvironment env) : base(uow)
        {
            _env = env;
        }

        public IEnumerable<LiabilityList>? GetList(PagingRequest request)
        {
            return Uow.Liabilities.GetList(request);
        }

        public LiabilityDto GetById(int payeeId)
        {
            var payee = Uow.Payees.GetById(payeeId);
            var liability = Uow.Liabilities.GetById(payeeId);

            if (payee == null && liability == null)
                return null;

            var dto = new LiabilityDto();

            if (payee != null)
                dto.InjectFrom(payee);

            if (liability != null)
                dto.InjectFrom(liability);

            return dto;
        }

        public bool NameExists(LiabilityDto dto)
        {
            return Uow.Payees.Exists(c => c.PayeeName.ToLower() == dto.PayeeName.ToLower() && c.PayeeId != dto.PayeeId && c.PayeeType.StartsWith(EnumHelper.PayeeType.L.ToString()));
        }

        public LiabilityDto Create(LiabilityDto dto)
        {
            var newPayeeId = GetMaxLiabilityId();

            var payee = new Payee();
            payee.InjectFrom(dto);
            payee.PayeeId = newPayeeId;

            Uow.Payees.Add(payee);
            Uow.Commit();

            var liability = new Liability();
            liability.InjectFrom(dto);
            liability.PayeeId = newPayeeId;

            Uow.Liabilities.Add(liability);
            Uow.Commit();

            Uow.Liabilities.InsertOpeningLoan(newPayeeId);

            return GetById(newPayeeId);
        }

        public LiabilityDto? Update(LiabilityDto dto)
        {
            var liability = Uow.Liabilities.GetById(dto.PayeeId);
            var existingPayee = Uow.Payees.GetById(dto.PayeeId);

            if (liability == null || existingPayee == null)
                return null;

            existingPayee.PayeeName = dto.PayeeName;
            existingPayee.StartDate = dto.StartDate;
            existingPayee.Balance = dto.Balance;
            existingPayee.Address = dto.Address;
            existingPayee.City = dto.City;
            existingPayee.State = dto.State;
            existingPayee.ZipCode = dto.ZipCode;
            existingPayee.UpdatedAt = DateTime.UtcNow;

            Uow.Payees.Update(existingPayee);

            liability.LegalName = dto.LegalName;
            liability.AccountNumber = dto.AccountNumber;
            liability.AccountId1 = dto.AccountId1;
            liability.AccountId2 = dto.AccountId2;
            liability.AccountId3 = dto.AccountId3;
            liability.AccountId4 = dto.AccountId4;

            Uow.Liabilities.Update(liability);

            Uow.Commit();

            return GetById(existingPayee.PayeeId);
        }

        public void Delete(int payeeId)
        {
            Uow.Payees.Delete(payeeId);
        }

        public int GetMaxLiabilityId()
        {
            var maxId = Uow.Liabilities.GetAll().Select(p => (int?)p.PayeeId).Max();
            return (maxId ?? 400000) + 1;
        }

        public PagingResponse<LiabilityTxList> GetTxPagedList(LiabilityTxListReq request)
        {
            var list = Uow.Liabilities.GetTxPagedList(request);

            var totalRecords = Uow.Liabilities.TxCount(request);

            return new PagingResponse<LiabilityTxList>(totalRecords, request.Pageno, request.Pagesize)
            {
                RowData = list,
            };
        }

        public int ImportTax(ImportTaxReq importTaxReq)
        {
            var txCount = 0;

            if (importTaxReq.TaxFile != null)
            {
                var excelFile = Path.Combine(_env.WebRootPath, "Payroll", importTaxReq.TaxFile.FileName);

                GC.Collect();

                if (File.Exists(excelFile))
                    File.Delete(excelFile);

                using (var fileStream = new FileStream(excelFile, FileMode.Create))
                {
                    importTaxReq.TaxFile.CopyTo(fileStream);
                }

                GC.Collect();

                importTaxReq.FilePath = excelFile;

                txCount = Uow.Liabilities.ImportTax(importTaxReq);
            }

            return txCount;
        }

        public VendorPayment SaveLoanPayment(LiabilityPaymentReq paymentReq)
        {
            var paymentId = Uow.Liabilities.SaveLoanPayment(paymentReq);

            return Uow.VendorPayments.GetById(paymentId);
        }

        public VendorPayment SaveCCPayment(LiabilityPaymentReq paymentReq)
        {
            var paymentId = Uow.Liabilities.SaveCCPayment(paymentReq);

            return Uow.VendorPayments.GetById(paymentId);
        }
    }
}
