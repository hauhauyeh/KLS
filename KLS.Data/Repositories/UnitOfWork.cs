using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Data.Repositories
{
    public class UnitOfWork : IUnitOfWork, IDisposable
    {
        private KLSDBContext DbContext;

        public UnitOfWork()
        {
            DbContext = new KLSDBContext();
        }

        public void Dispose()
        {
            Dispose(true);
            GC.SuppressFinalize(this);
        }

        private void Dispose(bool disposing)
        {
            if (!disposing)
            {
                DbContext?.Dispose();
            }
        }

        public void Commit()
        {
            DbContext.SaveChanges();
        }

        public IHolidayRepository Holidays { get { return new HolidayRepository(DbContext); } }

        public IUserRoleRepository UserRoles { get { return new UserRoleRepository(DbContext); } }

        public IPayeeRepository Payees { get { return new PayeeRepository(DbContext); } }

        public IUserRepository Users { get { return new UserRepository(DbContext); } }

        public IEmployeeRepository Employees { get { return new EmployeeRepository(DbContext); } }

        public ICustomerRepository Customers { get { return new CustomerRepository(DbContext); } }

        public IVendorRepository Vendors { get { return new VendorRepository(DbContext); } }

        public ITermRepository Terms { get { return new TermRepository(DbContext); } }

        public ITruckRepository Trucks { get { return new TruckRepository(DbContext); } }

        public ISystemSettingRepository SystemSettings { get { return new SystemSettingRepository(DbContext); } }
    }
}
