using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using Omu.ValueInjecter;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class EmployeeService : BaseService, IEmployeeService
    {
        public EmployeeService(IUnitOfWork uow) : base(uow)
        {
        }

        public IEnumerable<Payee> GetAllEmployees()
        {
            return Uow.Payees
                .GetAll().Include(e => e.Employee)
                .OrderByDescending(e => e.PayeeId)
                .ToList();
        }

        public Payee? GetEmployeeById(int payeeId)
        {
            return Uow.Payees.Find(c => c.PayeeId == payeeId).Include(c => c.Employee).FirstOrDefault();
        }

        public bool EmployeeExists(Payee employee)
        {
            return Uow.Payees.Exists(p => p.PayeeName.ToLower() == employee.PayeeName.ToLower() && p.PayeeId != employee.PayeeId && p.PayeeType == EnumHelper.PayeeType.E.ToString());
        }

        public Payee CreateEmployee(Payee payee)
        {
            var newPayeeId = GetMaxEmployeeId();
            payee.PayeeId = newPayeeId;

            if (payee.Employee != null)
            {
                payee.Employee.PayeeId = newPayeeId;
            }

            Uow.Payees.Add(payee);
            Uow.Commit();

            return payee;
        }

        public Payee? UpdateEmployee(Payee payee)
        {
            var employee = Uow.Employees.GetById(payee.PayeeId);
            var existingPayee = Uow.Payees.GetById(payee.PayeeId);

            if (employee == null || existingPayee == null)
                return null;

            // --- Update Payee Fields ---
            existingPayee.PayeeName = payee.PayeeName;
            existingPayee.Address = payee.Address;
            existingPayee.City = payee.City;
            existingPayee.State = payee.State;
            existingPayee.ZipCode = payee.ZipCode;
            existingPayee.PhoneDesc1 = payee.PhoneDesc1;
            existingPayee.Phone1 = payee.Phone1;
            existingPayee.PhoneDesc2 = payee.PhoneDesc2;
            existingPayee.Phone2 = payee.Phone2;
            existingPayee.PhoneDesc3 = payee.PhoneDesc3;
            existingPayee.Phone3 = payee.Phone3;
            existingPayee.PhoneDesc4 = payee.PhoneDesc4;
            existingPayee.Phone4 = payee.Phone4;
            existingPayee.Email = payee.Email;
            existingPayee.IsClosed = payee.IsClosed;
            existingPayee.StartDate = payee.StartDate;
            existingPayee.Notes = payee.Notes;
            existingPayee.Balance = payee.Balance;
            existingPayee.UpdatedAt = DateTime.UtcNow;

            Uow.Payees.Update(existingPayee);

            // --- Update Employee Fields ---
            var emp = payee.Employee;

            if (emp != null)
            {
                employee.FirstName = emp.FirstName;
                employee.MiddleName = emp.MiddleName;
                employee.LastName = emp.LastName;
                employee.Department = emp.Department;
                employee.EmploymentType = emp.EmploymentType;
                employee.SSN = emp.SSN;
                employee.DOB = emp.DOB;
                employee.DLN = emp.DLN;
                employee.PayFreq = emp.PayFreq;
                employee.HourOrSalary = emp.HourOrSalary;
                employee.Rate = emp.Rate;
                employee.SingleOrMarried = emp.SingleOrMarried;
                employee.W4Exempt = emp.W4Exempt;
                employee.K401 = emp.K401;
                employee.IRA = emp.IRA;
                employee.RothIRA = emp.RothIRA;
                employee.R1 = emp.R1;
                employee.R2 = emp.R2;
                employee.R3 = emp.R3;
                employee.HealthIns = emp.HealthIns;
                employee.VisionIns = emp.VisionIns;
                employee.DentalIns = emp.DentalIns;
                employee.ChildSup1 = emp.ChildSup1;
                employee.ChildSup2 = emp.ChildSup2;
                employee.ChildSup3 = emp.ChildSup3;
                employee.ChildSup4 = emp.ChildSup4;
                employee.ChildSup5 = emp.ChildSup5;
                employee.IsUsePayCheck = emp.IsUsePayCheck;
                employee.IsRestricted = emp.IsRestricted;
                employee.IsShowPastDueWarning = emp.IsShowPastDueWarning;
                employee.IsTextPriceChange = emp.IsTextPriceChange;
                employee.IsService = emp.IsService;

                Uow.Employees.Update(employee);
            }

            Uow.Commit();

            return existingPayee;
        }

        public void DeleteEmployee(int payeeId)
        {
            Uow.Payees.RemoveById(payeeId);
            Uow.Commit();
        }

        public int GetMaxEmployeeId()
        {
            var maxId = Uow.Employees.GetAll().Select(p => (int?)p.PayeeId).Max();
            return (maxId ?? 100000) + 1;
        }
    }
}
