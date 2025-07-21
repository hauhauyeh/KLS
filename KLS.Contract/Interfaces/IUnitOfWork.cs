using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface IUnitOfWork : IDisposable
    {
        IHolidayRepository Holidays { get; }

        IUserRoleRepository UserRoles { get; }

        IPayeeRepository Payees { get; }

        IUserRepository Users { get; }

        IEmployeeRepository Employees { get; }

        ISystemSettingRepository SystemSettings { get; }

        ICustomerRepository Customers { get; }

        IVendorRepository Vendors { get; }

        ITermRepository Terms { get; }

        ITruckRepository Trucks { get; }

        void Commit();
    }
}
