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
                .GetAll().Include(v => v.Vendor)
                .OrderByDescending(v => v.PayeeId)
                .ToList();
        }

        public Payee? GetById(int payeeId)
        {
            return Uow.Payees.Find(c => c.PayeeId == payeeId).Include(c => c.Vendor).FirstOrDefault();
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
            existingPayee.Notes = vendorDTO.Notes;
            existingPayee.UpdatedAt = DateTime.UtcNow;

            Uow.Payees.Update(existingPayee);

            // --- Update Vendor Fields ---

            if (vendor != null)
            {
                vendor.PmtCompany = vendor.PmtCompany;
                vendor.PmtAddress = vendor.PmtAddress;
                vendor.PmtCity = vendor.PmtCity;
                vendor.PmtState = vendor.PmtState;
                vendor.PmtZipCode = vendor.PmtZipCode;
                vendor.AccountNumber = vendor.AccountNumber;
                vendor.RoutingNumber = vendor.RoutingNumber;
                vendor.FreightRate = vendor.FreightRate;
                vendor.InterestRate = vendor.InterestRate;
                vendor.PmtSchedule1 = vendor.PmtSchedule1;
                vendor.PmtSchedule2 = vendor.PmtSchedule2;
                vendor.AcctCode1 = vendor.AcctCode1;
                vendor.AcctCode2 = vendor.AcctCode2;
                vendor.AcctCode3 = vendor.AcctCode3;
                vendor.AcctCode4 = vendor.AcctCode4;
                vendor.AcctCode5 = vendor.AcctCode5;
                vendor.AcctCode6 = vendor.AcctCode6;
                vendor.AcctCode6 = vendor.AcctCode6;
                vendor.DefaultPmtMethod = vendor.DefaultPmtMethod;
                vendor.IsShippingCarrier = vendor.IsShippingCarrier;
                vendor.IsVisibleToAdmin = vendor.IsVisibleToAdmin;

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

        public int GetMaxVendorId()
        {
            var maxId = Uow.Vendors.GetAll().Select(p => (int?)p.PayeeId).Max();
            return (maxId ?? 100000) + 1;
        }
    }
}
