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

        public EmployeeDTO? GetById(int payeeId)
        {
            var payee = Uow.Payees.GetById(payeeId);
            var employee = Uow.Employees.GetById(payeeId);
            var user = Uow.Users.GetById(payeeId);

            if (payee == null && employee == null)
                return null;

            var employeeDTO = new EmployeeDTO();

            if (payee != null)
                employeeDTO.InjectFrom(payee);

            if (employee != null)
                employeeDTO.InjectFrom(employee);

            if (user != null)
            {
                employeeDTO.RoleId = user.RoleId;
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

            Uow.Payees.Add(payee);

            var employee = new Employee();
            employee.InjectFrom(employeeDTO);
            employee.PayeeId = newPayeeId;

            Uow.Employees.Add(employee);

            if (!string.IsNullOrEmpty(employeeDTO.Username))
            {
                var user = new User
                {
                    PayeeId = newPayeeId,
                    RoleId = employeeDTO.RoleId,
                    Username = employeeDTO.Username,
                    PasswordHash = Utilities.Encrypt(employeeDTO.Password),
                    Inactive = employeeDTO.IsClosed
                };

                Uow.Users.Add(user);
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
            existingPayee.Notes = employeeDTO.Notes;
            existingPayee.UpdatedAt = DateTime.UtcNow;

            Uow.Payees.Update(existingPayee);

            // --- Update Employee Fields ---

            if (employee != null)
            {
                employee.FirstName = employee.FirstName;
                employee.MiddleName = employee.MiddleName;
                employee.LastName = employee.LastName;
                employee.Department = employee.Department;
                employee.EmploymentType = employee.EmploymentType;
                employee.SSN = employee.SSN;
                employee.DOB = employee.DOB;
                employee.DLN = employee.DLN;
                employee.PayFreq = employee.PayFreq;
                employee.HourOrSalary = employee.HourOrSalary;
                employee.Rate = employee.Rate;
                employee.SingleOrMarried = employee.SingleOrMarried;
                employee.W4Exempt = employee.W4Exempt;
                employee.K401 = employee.K401;
                employee.IRA = employee.IRA;
                employee.RothIRA = employee.RothIRA;
                employee.R1 = employee.R1;
                employee.R2 = employee.R2;
                employee.R3 = employee.R3;
                employee.HealthIns = employee.HealthIns;
                employee.VisionIns = employee.VisionIns;
                employee.DentalIns = employee.DentalIns;
                employee.ChildSup1 = employee.ChildSup1;
                employee.ChildSup2 = employee.ChildSup2;
                employee.ChildSup3 = employee.ChildSup3;
                employee.ChildSup4 = employee.ChildSup4;
                employee.ChildSup5 = employee.ChildSup5;
                employee.IsUsePayCheck = employee.IsUsePayCheck;
                employee.IsRestricted = employee.IsRestricted;
                employee.IsShowPastDueWarning = employee.IsShowPastDueWarning;
                employee.IsTextPriceChange = employee.IsTextPriceChange;
                employee.IsService = employee.IsService;

                Uow.Employees.Update(employee);
            }

            var user = Uow.Users.Find(c => c.PayeeId == employeeDTO.PayeeId).FirstOrDefault();

            if (user != null)
            {
                if (!string.IsNullOrEmpty(employeeDTO.Username))
                {
                    user.RoleId = employeeDTO.RoleId;
                    user.Username = employeeDTO.Username;
                    user.PasswordHash = Utilities.Encrypt(employeeDTO.Password);
                    user.Inactive = employeeDTO.IsClosed;

                    Uow.Users.Update(user);
                    Uow.Commit();
                }
            }
            else
            {
                if (!string.IsNullOrEmpty(employeeDTO.Username))
                {
                    var newuser = new User
                    {
                        PayeeId = employeeDTO.PayeeId,
                        RoleId = employeeDTO.RoleId,
                        Username = employeeDTO.Username,
                        PasswordHash = Utilities.Encrypt(employeeDTO.Password),
                        Inactive = employeeDTO.IsClosed
                    };

                    Uow.Users.Add(newuser);
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

        public int GetMaxEmployeeId()
        {
            var maxId = Uow.Employees.GetAll().Select(p => (int?)p.PayeeId).Max();
            return (maxId ?? 100000) + 1;
        }
    }
}
