using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class TempPayrollServiceService : BaseService, ITempPayrollServiceService
    {
        public TempPayrollServiceService(IUnitOfWork uow) : base(uow)
        {

        }

        public IEnumerable<TempPayrollService> GetList(int payrollServiceId)
        {
            var services = Uow.TempPayrollServices.Find(c => c.EmpId == UserContext.EmpId && c.PayrollServiceId == payrollServiceId).ToList();

            foreach (var temp in services)
            {
                var payee = Uow.Payees.GetById(temp.PayeeId);

                if (payee != null)
                    temp.PayeeName = payee.PayeeName;
            }

            return services;
        }

        public bool EmployeeExists(TempPayrollService tempService)
        {
            return Uow.TempPayrollServices.Exists(c => c.PayeeId == tempService.PayeeId && c.ServiceCode == tempService.ServiceCode && c.TempPayrollId != tempService.TempPayrollId && (c.ReferenceId != null && c.ReferenceId == tempService.ReferenceId));
        }

        public TempPayrollService Create(TempPayrollService tempService)
        {
            var payee = Uow.Payees.GetById(tempService.PayeeId);

            if (payee.PayeeType != EnumHelper.PayeeType.E.ToString())
            {
                tempService.ServiceCode = EnumHelper.PayrollServiceCode.PAYROLLTAXPMT.ToString();
            }

            //restrict duplicate employee. 
            var isExist = EmployeeExists(tempService);

            if (isExist)
                throw new Exception("Employee already exists");

            tempService.PayeeName = payee.PayeeName;
            tempService.EmpId = UserContext.EmpId;

            Uow.TempPayrollServices.Add(tempService);
            Uow.Commit();

            return tempService;
        }

        public TempPayrollService Update(TempPayrollService tempService)
        {
            var oldTemp = Uow.TempPayrollServices.GetById(tempService.TempPayrollId);

            if (oldTemp != null)
            {
                oldTemp.PaymentAmount = tempService.PaymentAmount;
                oldTemp.ServiceCode = tempService.ServiceCode;
                oldTemp.ReferenceId = tempService.ReferenceId;
                oldTemp.FromAccountId = tempService.FromAccountId;

                var isExist = EmployeeExists(tempService);

                if (isExist)
                    throw new Exception("Employee already exists");

                Uow.TempPayrollServices.Update(oldTemp);
                Uow.Commit();
            }

            return oldTemp;
        }

        public void Delete(int tempId)
        {
            Uow.TempPayrollServices.RemoveById(tempId);
            Uow.Commit();
        }
    }
}
