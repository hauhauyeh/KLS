using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class TempPayrollDetailService : BaseService, ITempPayrollDetailService
    {
        public TempPayrollDetailService(IUnitOfWork uow) : base(uow)
        {

        }

        public ICollection<TempPayrollDetail>? GetTempPayrollList(int vendorPaymentId)
        {
            return Uow.TempPayrollDetails.Find(c => c.EmpId == UserContext.EmpId && c.VendorPaymentId == vendorPaymentId).Include(c => c.Payee).ToList();
        }

        public TempPayrollDetail GetById(int tempPayrollId)
        {
            return Uow.TempPayrollDetails.Find(c => c.TempPayrollId == tempPayrollId).Include(c => c.Payee).FirstOrDefault()!;
        }

        public TempPayrollDetail Update(TempPayrollDetail tempPayrollDetail)
        {
            Uow.TempPayrollDetails.UpdateTempPayroll(tempPayrollDetail);

            return GetById(tempPayrollDetail.TempPayrollId);
        }
    }
}
