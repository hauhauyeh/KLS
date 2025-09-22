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

        public IEnumerable<EmployeeList> GetAllEmployees(EmpReq empReq)
        {
            return Uow.Employees.GetAllEmployees(empReq);
        }

        public EmployeeDTO? GetById(int payeeId)
        {
            var payee = Uow.Payees.GetById(payeeId);
            var employee = Uow.Employees.GetById(payeeId);
            var user = Uow.SystemUsers.Find(u => u.PayeeId == payeeId).FirstOrDefault();

            if (payee == null && employee == null)
                return null;

            var employeeDTO = new EmployeeDTO();

            if (payee != null)
                employeeDTO.InjectFrom(payee);

            if (employee != null)
                employeeDTO.InjectFrom(employee);

            if (user != null)
            {
                employeeDTO.RoleId = user.SystemRoleId;
                employeeDTO.Username = user.Username;
                employeeDTO.Password = Utilities.Decrypt(user.PasswordHash);
            }

            return employeeDTO;
        }

        public bool EmployeeExists(EmployeeDTO employeeDTO)
        {
            return Uow.Payees.Exists(p => p.PayeeName.ToLower() == employeeDTO.PayeeName.ToLower() && p.PayeeId != employeeDTO.PayeeId && p.PayeeType == EnumHelper.PayeeType.E.ToString());
        }

        public EmployeeDTO CreateEmployee(EmployeeDTO employeeDTO)
        {
            var newPayeeId = GetMaxEmployeeId();

            var payee = new Payee();
            payee.InjectFrom(employeeDTO);
            payee.PayeeId = newPayeeId;
            payee.PayeeType = EnumHelper.PayeeType.E.ToString();

            Uow.Payees.Add(payee);

            var employee = new Employee();
            employee.InjectFrom(employeeDTO);
            employee.PayeeId = newPayeeId;

            Uow.Employees.Add(employee);

            if (!string.IsNullOrEmpty(employeeDTO.Username))
            {
                var user = new SystemUser
                {
                    PayeeId = newPayeeId,
                    SystemRoleId = employeeDTO.RoleId,
                    Username = employeeDTO.Username,
                    PasswordHash = Utilities.Encrypt(employeeDTO.Password),
                    Inactive = employeeDTO.IsClosed
                };

                Uow.SystemUsers.Add(user);
            }

            Uow.Commit();

            return employeeDTO;
        }

        public EmployeeDTO? UpdateEmployee(EmployeeDTO employeeDTO)
        {
            var employee = Uow.Employees.GetById(employeeDTO.PayeeId);
            var existingPayee = Uow.Payees.GetById(employeeDTO.PayeeId);

            if (employee == null || existingPayee == null)
                return null;

            // --- Update Payee Fields ---
            existingPayee.PayeeName = employeeDTO.PayeeName;
            existingPayee.Address = employeeDTO.Address;
            existingPayee.City = employeeDTO.City;
            existingPayee.State = employeeDTO.State;
            existingPayee.ZipCode = employeeDTO.ZipCode;
            existingPayee.PhoneDesc1 = employeeDTO.PhoneDesc1;
            existingPayee.Phone1 = employeeDTO.Phone1;
            existingPayee.PhoneDesc2 = employeeDTO.PhoneDesc2;
            existingPayee.Phone2 = employeeDTO.Phone2;
            existingPayee.PhoneDesc3 = employeeDTO.PhoneDesc3;
            existingPayee.Phone3 = employeeDTO.Phone3;
            existingPayee.PhoneDesc4 = employeeDTO.PhoneDesc4;
            existingPayee.Phone4 = employeeDTO.Phone4;
            existingPayee.IsClosed = employeeDTO.IsClosed;
            existingPayee.StartDate = employeeDTO.StartDate;
            existingPayee.Balance = employeeDTO.Balance;
            existingPayee.Notes = employeeDTO.Notes;
            existingPayee.UpdatedAt = DateTime.UtcNow;

            Uow.Payees.Update(existingPayee);

            // --- Update Employee Fields ---

            if (employee != null)
            {
                employee.FirstName = employeeDTO.FirstName;
                employee.MiddleName = employeeDTO.MiddleName;
                employee.LastName = employeeDTO.LastName;
                employee.Department = employeeDTO.Department;
                employee.EmploymentType = employeeDTO.EmploymentType;
                employee.SSN = employeeDTO.SSN;
                employee.DOB = employeeDTO.DOB;
                employee.DLN = employeeDTO.DLN;
                employee.PayFreq = employeeDTO.PayFreq;
                employee.HourOrSalary = employeeDTO.HourOrSalary;
                employee.Rate = employeeDTO.Rate;
                employee.SingleOrMarried = employeeDTO.SingleOrMarried;
                employee.W4Exempt = employeeDTO.W4Exempt;
                employee.K401 = employeeDTO.K401;
                employee.IRA = employeeDTO.IRA;
                employee.RothIRA = employeeDTO.RothIRA;
                employee.R1 = employeeDTO.R1;
                employee.R2 = employeeDTO.R2;
                employee.R3 = employeeDTO.R3;
                employee.HealthIns = employeeDTO.HealthIns;
                employee.VisionIns = employeeDTO.VisionIns;
                employee.DentalIns = employeeDTO.DentalIns;
                employee.ChildSup1 = employeeDTO.ChildSup1;
                employee.ChildSup2 = employeeDTO.ChildSup2;
                employee.ChildSup3 = employeeDTO.ChildSup3;
                employee.ChildSup4 = employeeDTO.ChildSup4;
                employee.ChildSup5 = employeeDTO.ChildSup5;
                employee.IsUsePayCheck = employeeDTO.IsUsePayCheck;
                employee.IsRestricted = employeeDTO.IsRestricted;
                employee.IsShowPastDueWarning = employeeDTO.IsShowPastDueWarning;
                employee.IsTextPriceChange = employeeDTO.IsTextPriceChange;
                employee.IsService = employeeDTO.IsService;

                Uow.Employees.Update(employee);
            }

            var user = Uow.SystemUsers.Find(c => c.PayeeId == employeeDTO.PayeeId).FirstOrDefault();

            if (user != null)
            {
                if (!string.IsNullOrEmpty(employeeDTO.Username))
                {
                    user.SystemRoleId = employeeDTO.RoleId;
                    user.Username = employeeDTO.Username;
                    user.PasswordHash = Utilities.Encrypt(employeeDTO.Password);
                    user.Inactive = employeeDTO.IsClosed;

                    Uow.SystemUsers.Update(user);
                    Uow.Commit();
                }
            }
            else
            {
                if (!string.IsNullOrEmpty(employeeDTO.Username))
                {
                    var newuser = new SystemUser
                    {
                        PayeeId = employeeDTO.PayeeId,
                        SystemRoleId = employeeDTO.RoleId,
                        Username = employeeDTO.Username,
                        PasswordHash = Utilities.Encrypt(employeeDTO.Password),
                        Inactive = employeeDTO.IsClosed
                    };

                    Uow.SystemUsers.Add(newuser);
                }
            }

            Uow.Commit();

            return employeeDTO;
        }

        public void DeleteEmployee(int payeeId)
        {
            Uow.Payees.RemoveById(payeeId);
            Uow.Commit();
        }

        public IEnumerable<PayeeSearch>? SearchEmployee(PayeeSearchReq searchReq)
        {
            return Uow.Employees.SearchEmployee(searchReq);
        }

        private int GetMaxEmployeeId()
        {
            var maxId = Uow.Employees.GetAll().Select(p => (int?)p.PayeeId).Max();
            return (maxId ?? 100000) + 1;
        }
    }
}
