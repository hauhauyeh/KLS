using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
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

        public bool VendorExists(Payee vendor)
        {
            return Uow.Payees.Exists(p => p.PayeeName.ToLower() == vendor.PayeeName.ToLower() && p.PayeeId != vendor.PayeeId && p.PayeeType == EnumHelper.PayeeType.E.ToString());
        }

        public Payee CreateVendor(Payee payee)
        {
            var newPayeeId = GetMaxVendorId();
            payee.PayeeId = newPayeeId;

            if (payee.Vendor != null)
            {
                payee.Vendor.PayeeId = newPayeeId;
            }

            Uow.Payees.Add(payee);
            Uow.Commit();

            return payee;
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
