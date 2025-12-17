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
    public class EmployeeService : BaseService, IEmployeeService
    {
        public EmployeeService(IUnitOfWork uow) : base(uow)
        {
        }

        public IEnumerable<EmployeeList> GetAllEmployees(EmpReq empReq)
        {
            return Uow.Employees.GetAllEmployees(empReq);
        }

        public ICollection<EmployeeList> GetActiveEmployees()
        {
            var payees = Uow.Payees.Find(c => c.IsClosed == false && c.PayeeType == EnumHelper.PayeeType.E.ToString()).OrderBy(c => c.PayeeName).ToList();

            var employees = payees.Select(p => new EmployeeList().InjectFrom(p)).Cast<EmployeeList>()
                .ToList();

            return employees;
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
                employee.PayFrequency = employeeDTO.PayFrequency;
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
                employee.HealthInsurance = employeeDTO.HealthInsurance;
                employee.VisionInsurance = employeeDTO.VisionInsurance;
                employee.DentalInsurance = employeeDTO.DentalInsurance;
                employee.ChildSupport1 = employeeDTO.ChildSupport1;
                employee.ChildSupport2 = employeeDTO.ChildSupport2;
                employee.ChildSupport3 = employeeDTO.ChildSupport3;
                employee.ChildSupport4 = employeeDTO.ChildSupport4;
                employee.ChildSupport5 = employeeDTO.ChildSupport5;
                employee.IsUsePayCheck = employeeDTO.IsUsePayCheck;
                employee.HasOutsideAccess = employeeDTO.HasOutsideAccess;
                employee.HasPastDueWarning = employeeDTO.HasPastDueWarning;
                employee.IsPriceChangeNotify = employeeDTO.IsPriceChangeNotify;
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
