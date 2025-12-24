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
        public VendorService(IUnitOfWork uow) : base(uow)
        {

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
            return Uow.Payees.Exists(p => p.PayeeName.ToLower() == vendorDTO.PayeeName.ToLower() && p.PayeeId != vendorDTO.PayeeId && p.PayeeType == EnumHelper.PayeeType.E.ToString());
        }

        public VendorDTO Create(VendorDTO vendorDTO)
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
            existingPayee.Email = vendorDTO.Email;
            existingPayee.IsClosed = vendorDTO.IsClosed;
            existingPayee.StartDate = vendorDTO.StartDate;
            existingPayee.Balance = vendorDTO.Balance;
            existingPayee.TermId = vendorDTO.TermId;
            existingPayee.Notes = vendorDTO.Notes;
            existingPayee.PhoneDesc1 = vendorDTO.PhoneDesc1;
            existingPayee.Phone1 = vendorDTO.Phone1;
            existingPayee.PhoneDesc2 = vendorDTO.PhoneDesc2;
            existingPayee.Phone2 = vendorDTO.Phone2;
            existingPayee.PhoneDesc3 = vendorDTO.PhoneDesc3;
            existingPayee.Phone3 = vendorDTO.Phone3;
            existingPayee.PhoneDesc4 = vendorDTO.PhoneDesc4;
            existingPayee.Phone4 = vendorDTO.Phone4;
            existingPayee.PhoneDesc5 = vendorDTO.PhoneDesc5;
            existingPayee.Phone5 = vendorDTO.Phone5;
            existingPayee.PhoneDesc6 = vendorDTO.PhoneDesc6;
            existingPayee.Phone6 = vendorDTO.Phone6;

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

        public void Delete(int payeeId)
        {
            Uow.Payees.RemoveById(payeeId);
            Uow.Commit();
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

        public IEnumerable<VendorSearchDTO>? GetActive()
        {
            return Uow.Payees.Find(p => p.PayeeType == EnumHelper.PayeeType.V.ToString() && p.IsClosed == false).OrderBy(p => p.PayeeName).Select(p => new VendorSearchDTO { PayeeId = p.PayeeId, PayeeName = p.PayeeName });
        }
    }
}
