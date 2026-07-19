using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Omu.ValueInjecter;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class VendorService : BaseService, IVendorService
    {
        private readonly IExportService _exportService;

        public VendorService(IUnitOfWork uow, IExportService exportService) : base(uow)
        {
            _exportService = exportService;
        }

        public PagingResponse<VendorList> GetPagedList(VendorListReq vendorListReq)
        {
            var list = Uow.Vendors.GetPagedList(vendorListReq);

            var totalRecords = Uow.Vendors.Count(vendorListReq);

            return new PagingResponse<VendorList>(totalRecords, vendorListReq.Pageno, vendorListReq.Pagesize)
            {
                RowData = list,
            };
        }

        public VendorDTO? GetById(int payeeId)
        {
            var payee = Uow.Payees.GetById(payeeId);
            var vendor = Uow.Vendors.GetById(payeeId);

            if (payee == null && vendor == null)
                return null;

            var vendorDTO = new VendorDTO();

            if (payee != null)
                vendorDTO.InjectFrom(payee);

            if (vendor != null)
                vendorDTO.InjectFrom(vendor);

            var term = Uow.Terms.GetById(payee.TermId ?? 0);

            vendorDTO.TermName = term?.TermName;

            return vendorDTO;
        }

        public bool VendorExists(VendorDTO vendorDTO)
        {
            return Uow.Payees.Exists(p => p.PayeeName.ToLower() == vendorDTO.PayeeName.ToLower() && p.PayeeId != vendorDTO.PayeeId && p.PayeeType == EnumHelper.PayeeType.V.ToString());
        }

        public VendorDTO Create(VendorDTO vendorDTO)
        {
            var newPayeeId = GetMaxVendorId();

            var payee = new Payee();
            payee.InjectFrom(vendorDTO);
            NormalizePayeeContactFields(payee);
            payee.PayeeId = newPayeeId;
            payee.PayeeType = EnumHelper.PayeeType.V.ToString();

            Uow.Payees.Add(payee);
            Uow.Commit();

            var vendor = new Vendor();
            vendor.InjectFrom(vendorDTO);
            vendor.PayeeId = newPayeeId;

            Uow.Vendors.Add(vendor);
            Uow.Commit();

            return GetById(newPayeeId);
        }

        public VendorDTO? Update(VendorDTO vendorDTO)
        {
            var vendor = Uow.Vendors.GetById(vendorDTO.PayeeId);
            var existingPayee = Uow.Payees.GetById(vendorDTO.PayeeId);

            if (vendor == null || existingPayee == null)
                return null;

            // --- Update Payee Fields ---
            existingPayee.PayeeName = vendorDTO.PayeeName;
            existingPayee.Address = vendorDTO.Address;
            existingPayee.City = vendorDTO.City;
            existingPayee.State = vendorDTO.State;
            existingPayee.ZipCode = vendorDTO.ZipCode;
            existingPayee.Country = vendorDTO.Country;
            existingPayee.AddressLine2 = CleanText(vendorDTO.AddressLine2);
            existingPayee.CountryCode = CleanUpperText(vendorDTO.CountryCode);
            existingPayee.Continent = CleanText(vendorDTO.Continent);
            existingPayee.Province = CleanText(vendorDTO.Province);
            existingPayee.PostalCode = CleanText(vendorDTO.PostalCode);
            existingPayee.CurrencyCode = CleanUpperText(vendorDTO.CurrencyCode);
            existingPayee.Locale = CleanText(vendorDTO.Locale);
            existingPayee.Timezone = CleanText(vendorDTO.Timezone);
            existingPayee.TaxRegistrationNumber = CleanText(vendorDTO.TaxRegistrationNumber);
            existingPayee.Email = CleanText(vendorDTO.Email);
            existingPayee.IsClosed = vendorDTO.IsClosed;
            existingPayee.StartDate = vendorDTO.StartDate;
            existingPayee.Balance = vendorDTO.Balance;
            existingPayee.TermId = vendorDTO.TermId;
            existingPayee.Notes = vendorDTO.Notes;
            existingPayee.PhoneDesc1 = CleanText(vendorDTO.PhoneDesc1);
            existingPayee.Phone1 = CleanText(vendorDTO.Phone1);
            existingPayee.PhoneDesc2 = CleanText(vendorDTO.PhoneDesc2);
            existingPayee.Phone2 = CleanText(vendorDTO.Phone2);
            existingPayee.PhoneDesc3 = CleanText(vendorDTO.PhoneDesc3);
            existingPayee.Phone3 = CleanText(vendorDTO.Phone3);
            existingPayee.PhoneDesc4 = CleanText(vendorDTO.PhoneDesc4);
            existingPayee.Phone4 = CleanText(vendorDTO.Phone4);
            existingPayee.PhoneDesc5 = CleanText(vendorDTO.PhoneDesc5);
            existingPayee.Phone5 = CleanText(vendorDTO.Phone5);
            existingPayee.PhoneDesc6 = CleanText(vendorDTO.PhoneDesc6);
            existingPayee.Phone6 = CleanText(vendorDTO.Phone6);

            existingPayee.UpdatedAt = DateTime.UtcNow;

            Uow.Payees.Update(existingPayee);

            // --- Update Vendor Fields ---

            if (vendor != null)
            {
                vendor.CompanyName = vendorDTO.CompanyName;
                vendor.PaymentAddress = vendorDTO.PaymentAddress;
                vendor.PaymentCity = vendorDTO.PaymentCity;
                vendor.PaymentState = vendorDTO.PaymentState;
                vendor.PaymentZipCode = vendorDTO.PaymentZipCode;
                vendor.AccountNumber = vendorDTO.AccountNumber;
                vendor.RoutingNumber = vendorDTO.RoutingNumber;
                vendor.InterestRate = vendorDTO.InterestRate;
                vendor.AccountId1 = vendorDTO.AccountId1;
                vendor.AccountId2 = vendorDTO.AccountId2;
                vendor.AccountId3 = vendorDTO.AccountId3;
                vendor.AccountId4 = vendorDTO.AccountId4;
                vendor.AccountId5 = vendorDTO.AccountId5;
                vendor.AccountId6 = vendorDTO.AccountId6;
                vendor.DefaultPaymentMethod = vendorDTO.DefaultPaymentMethod;
                vendor.IsShippingCarrier = vendorDTO.IsShippingCarrier;
                vendor.IsVisibleToAdmin = vendorDTO.IsVisibleToAdmin;

                Uow.Vendors.Update(vendor);
            }

            Uow.Commit();

            return vendorDTO;
        }

        public void Delete(int payeeId)
        {
            Uow.Payees.Delete(payeeId);
        }

        public IEnumerable<VendorSearchDTO>? Search(PayeeSearchReq searchReq)
        {
            return Uow.Vendors.Search(searchReq);
        }

        public int GetMaxVendorId()
        {
            var maxId = Uow.Vendors.GetAll().Select(p => (int?)p.PayeeId).Max();
            return (maxId ?? 200000) + 1;
        }

        private static void NormalizePayeeContactFields(Payee payee)
        {
            payee.Email = CleanText(payee.Email);
            payee.AddressLine2 = CleanText(payee.AddressLine2);
            payee.CountryCode = CleanUpperText(payee.CountryCode);
            payee.Continent = CleanText(payee.Continent);
            payee.Province = CleanText(payee.Province);
            payee.PostalCode = CleanText(payee.PostalCode);
            payee.CurrencyCode = CleanUpperText(payee.CurrencyCode);
            payee.Locale = CleanText(payee.Locale);
            payee.Timezone = CleanText(payee.Timezone);
            payee.TaxRegistrationNumber = CleanText(payee.TaxRegistrationNumber);
            payee.PhoneDesc1 = CleanText(payee.PhoneDesc1);
            payee.Phone1 = CleanText(payee.Phone1);
            payee.PhoneDesc2 = CleanText(payee.PhoneDesc2);
            payee.Phone2 = CleanText(payee.Phone2);
            payee.PhoneDesc3 = CleanText(payee.PhoneDesc3);
            payee.Phone3 = CleanText(payee.Phone3);
            payee.PhoneDesc4 = CleanText(payee.PhoneDesc4);
            payee.Phone4 = CleanText(payee.Phone4);
            payee.PhoneDesc5 = CleanText(payee.PhoneDesc5);
            payee.Phone5 = CleanText(payee.Phone5);
            payee.PhoneDesc6 = CleanText(payee.PhoneDesc6);
            payee.Phone6 = CleanText(payee.Phone6);
        }

        private static string? CleanText(string? value)
        {
            var text = value?.Trim();
            return string.IsNullOrWhiteSpace(text) ? null : text;
        }

        private static string? CleanUpperText(string? value)
        {
            return CleanText(value)?.ToUpperInvariant();
        }

        public IEnumerable<VendorSearchDTO>? GetActive()
        {
            return Uow.Payees.Find(p => p.PayeeType == EnumHelper.PayeeType.V.ToString() && p.IsClosed == false).OrderBy(p => p.PayeeName).Select(p => new VendorSearchDTO { PayeeId = p.PayeeId, PayeeName = p.PayeeName });
        }

        public IEnumerable<VendorSearchDTO>? ShippingCarriers()
        {
            var payees = Uow.Payees.Find(p => p.PayeeType == EnumHelper.PayeeType.V.ToString() && !p.IsClosed);
            var vendors = Uow.Vendors.Find(v => v.IsShippingCarrier);

            return (from p in payees
                    join v in vendors on p.PayeeId equals v.PayeeId
                    orderby p.PayeeName
                    select new VendorSearchDTO
                    {
                        PayeeId = p.PayeeId,
                        PayeeName = p.PayeeName
                    })
                   .ToList();
        }

        public byte[] Export()
        {
            var vendors = Uow.Vendors.Export();

            return _exportService.ToExcel(vendors, "Vendor");
        }
    }
}
