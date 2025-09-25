using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
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
        public VendorService(IUnitOfWork uow) : base(uow)
        {

        }

        public IEnumerable<Payee> GetAllVendors()
        {
            return Uow.Payees
                .Find(p => p.PayeeType == EnumHelper.PayeeType.V.ToString()).Include(v => v.Vendor)
                .OrderByDescending(v => v.PayeeId)
                .ToList();
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

            return vendorDTO;
        }

        public bool VendorExists(VendorDTO vendorDTO)
        {
            return Uow.Payees.Exists(p => p.PayeeName.ToLower() == vendorDTO.PayeeName.ToLower() && p.PayeeId != vendorDTO.PayeeId && p.PayeeType == EnumHelper.PayeeType.E.ToString());
        }

        public VendorDTO CreateVendor(VendorDTO vendorDTO)
        {
            var newPayeeId = GetMaxVendorId();

            var payee = new Payee();
            payee.InjectFrom(vendorDTO);
            payee.PayeeId = newPayeeId;
            payee.PayeeType = EnumHelper.PayeeType.V.ToString();

            Uow.Payees.Add(payee);

            var vendor = new Vendor();
            vendor.InjectFrom(vendorDTO);
            vendor.PayeeId = newPayeeId;

            Uow.Vendors.Add(vendor);
            Uow.Commit();

            return vendorDTO;
        }

        public VendorDTO? UpdateVendor(VendorDTO vendorDTO)
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
            existingPayee.PhoneDesc1 = vendorDTO.PhoneDesc1;
            existingPayee.Phone1 = vendorDTO.Phone1;
            existingPayee.PhoneDesc2 = vendorDTO.PhoneDesc2;
            existingPayee.Phone2 = vendorDTO.Phone2;
            existingPayee.PhoneDesc3 = vendorDTO.PhoneDesc3;
            existingPayee.Phone3 = vendorDTO.Phone3;
            existingPayee.PhoneDesc4 = vendorDTO.PhoneDesc4;
            existingPayee.Phone4 = vendorDTO.Phone4;
            existingPayee.IsClosed = vendorDTO.IsClosed;
            existingPayee.StartDate = vendorDTO.StartDate;
            existingPayee.Balance = vendorDTO.Balance;
            existingPayee.TermName = vendorDTO.TermName;
            existingPayee.Notes = vendorDTO.Notes;
            existingPayee.UpdatedAt = DateTime.UtcNow;

            Uow.Payees.Update(existingPayee);

            // --- Update Vendor Fields ---

            if (vendor != null)
            {
                //vendor.PmtCompany = vendorDTO.PmtCompany;
                //vendor.PmtAddress = vendorDTO.PmtAddress;
                //vendor.PmtCity = vendorDTO.PmtCity;
                //vendor.PmtState = vendorDTO.PmtState;
                //vendor.PmtZipCode = vendorDTO.PmtZipCode;
                vendor.AccountNumber = vendorDTO.AccountNumber;
                vendor.RoutingNumber = vendorDTO.RoutingNumber;
                vendor.FreightRate = vendorDTO.FreightRate;
                vendor.InterestRate = vendorDTO.InterestRate;
                vendor.PaymentSchedule1 = vendorDTO.PaymentSchedule1;
                vendor.PaymentSchedule2 = vendorDTO.PaymentSchedule2;
                vendor.AccountCode1 = vendorDTO.AccountCode1;
                vendor.AccountCode2 = vendorDTO.AccountCode2;
                vendor.AccountCode3 = vendorDTO.AccountCode3;
                vendor.AccountCode4 = vendorDTO.AccountCode4;
                vendor.AccountCode5 = vendorDTO.AccountCode5;
                vendor.AccountCode6 = vendorDTO.AccountCode6;
                //vendor.AccountCode6 = vendorDTO.AccountCode6;
                vendor.DefaultPaymentMethod = vendorDTO.DefaultPaymentMethod;
                vendor.IsShippingCarrier = vendorDTO.IsShippingCarrier;
                vendor.IsVisibleToAdmin = vendorDTO.IsVisibleToAdmin;

                Uow.Vendors.Update(vendor);
            }

            Uow.Commit();

            return vendorDTO;
        }

        public void DeleteVendor(int payeeId)
        {
            Uow.Payees.RemoveById(payeeId);
            Uow.Commit();
        }

        public IEnumerable<PayeeSearch>? SearchVendor(PayeeSearchReq searchReq)
        {
            return Uow.Vendors.SearchVendor(searchReq);
        }

        public int GetMaxVendorId()
        {
            var maxId = Uow.Vendors.GetAll().Select(p => (int?)p.PayeeId).Max();
            return (maxId ?? 200000) + 1;
        }
    }
}
