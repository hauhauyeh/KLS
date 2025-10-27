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
            existingPayee.IsClosed = vendorDTO.IsClosed;
            existingPayee.StartDate = vendorDTO.StartDate;
            existingPayee.Balance = vendorDTO.Balance;
            existingPayee.TermId = vendorDTO.TermId;
            existingPayee.Notes = vendorDTO.Notes;
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
                vendor.FreightRate = vendorDTO.FreightRate;
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

        public void DeleteVendor(int payeeId)
        {
            Uow.Payees.RemoveById(payeeId);
            Uow.Commit();
        }

        public IEnumerable<VendorSearchDTO>? SearchVendor(PayeeSearchReq searchReq)
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
