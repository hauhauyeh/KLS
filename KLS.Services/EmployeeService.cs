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

        public IEnumerable<EmployeeList> GetPagedList(EmpReq empReq)
        {
            return Uow.Employees.GetPagedList(empReq);
        }

        public IEnumerable<EmployeeList>? GetActive()
        {
            var payees = Uow.Payees.Find(c => c.IsClosed == false && c.PayeeType == EnumHelper.PayeeType.E.ToString()).OrderBy(c => c.PayeeName).ToList();

            var employees = payees.Select(p => new EmployeeList().InjectFrom(p)).Cast<EmployeeList>()
                .ToList();

            return employees;
        }

        public IEnumerable<EmployeeList>? GetDrivers()
        {
            var payees = Uow.Payees.Find(c => c.IsClosed == false && c.PayeeType == EnumHelper.PayeeType.E.ToString());
            var employees = Uow.Employees.Find(c => c.Department == "Warehouse" || c.Department == "Driver");

            var result = from p in payees
                         join e in employees on p.PayeeId equals e.PayeeId
                         select new EmployeeList
                         {
                             PayeeId = p.PayeeId,
                             PayeeName = p.PayeeName,
                             Department = e.Department
                         };

            return result.OrderBy(c => c.PayeeName).ToList();
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

            // Assigned after the InjectFrom calls: Payee also has an Email column, so without this
            // the modal would show Payee.Email. SystemUser is the source of truth for the login email.
            employeeDTO.Email = user?.Email;

            return employeeDTO;
        }

        public bool NameExists(EmployeeDTO employeeDTO)
        {
            return Uow.Payees.Exists(p => p.PayeeName.ToLower() == employeeDTO.PayeeName.ToLower() && p.PayeeId != employeeDTO.PayeeId && p.PayeeType == EnumHelper.PayeeType.E.ToString());
        }

        public EmployeeDTO Create(EmployeeDTO employeeDTO)
        {
            var newPayeeId = GetMaxEmployeeId();

            var email = string.IsNullOrWhiteSpace(employeeDTO.Email) ? null : employeeDTO.Email.Trim();
            var hasLogin = !string.IsNullOrEmpty(employeeDTO.Username) || email != null;

            var payee = new Payee();
            payee.InjectFrom(employeeDTO);
            payee.PayeeId = newPayeeId;
            payee.PayeeType = EnumHelper.PayeeType.E.ToString();
            payee.Email = email;

            Uow.Payees.Add(payee);
            Uow.Commit();

            var employee = new Employee();
            employee.InjectFrom(employeeDTO);
            employee.PayeeId = newPayeeId;

            Uow.Employees.Add(employee);

            if (hasLogin)
            {
                var user = new SystemUser
                {
                    PayeeId = newPayeeId,
                    SystemRoleId = employeeDTO.RoleId,
                    Email = email,
                    Username = employeeDTO.Username,
                    PasswordHash = Utilities.Encrypt(employeeDTO.Password),
                    Inactive = employeeDTO.IsClosed
                };

                Uow.SystemUsers.Add(user);
            }

            Uow.Commit();

            return employeeDTO;
        }

        public EmployeeDTO? Update(EmployeeDTO employeeDTO)
        {
            var employee = Uow.Employees.GetById(employeeDTO.PayeeId);
            var existingPayee = Uow.Payees.GetById(employeeDTO.PayeeId);

            if (employee == null || existingPayee == null)
                return null;

            var email = string.IsNullOrWhiteSpace(employeeDTO.Email) ? null : employeeDTO.Email.Trim();
            var hasLogin = !string.IsNullOrEmpty(employeeDTO.Username) || email != null;

            // --- Update Payee Fields ---
            existingPayee.PayeeName = employeeDTO.PayeeName;
            existingPayee.Email = email;
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
                if (hasLogin)
                {
                    user.SystemRoleId = employeeDTO.RoleId;
                    user.Email = email;
                    user.Username = employeeDTO.Username;
                    user.PasswordHash = Utilities.Encrypt(employeeDTO.Password);
                    user.Inactive = employeeDTO.IsClosed;

                    Uow.SystemUsers.Update(user);
                    Uow.Commit();
                }
            }
            else
            {
                if (hasLogin)
                {
                    var newuser = new SystemUser
                    {
                        PayeeId = employeeDTO.PayeeId,
                        SystemRoleId = employeeDTO.RoleId,
                        Email = email,
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

        public void Delete(int payeeId)
        {
            Uow.Payees.Delete(payeeId);
        }

        public IEnumerable<PayeeSearch>? Search(PayeeSearchReq searchReq)
        {
            return Uow.Employees.Search(searchReq);
        }

        private int GetMaxEmployeeId()
        {
            var maxId = Uow.Employees.GetAll().Select(p => (int?)p.PayeeId).Max();
            return (maxId ?? 100000) + 1;
        }
    }
}
