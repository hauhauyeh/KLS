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

        public IUserAccountRepository UserAccounts { get { return new UserAccountRepository(DbContext); } }

        public IEmployeeRepository Employees { get { return new EmployeeRepository(DbContext); } }

        public IEmailSettingRepository EmailSettings { get { return new EmailSettingRepository(DbContext); } }

        public ICustomerRepository Customers { get { return new CustomerRepository(DbContext); } }

        public IVendorRepository Vendors { get { return new VendorRepository(DbContext); } }

        public ITermRepository Terms { get { return new TermRepository(DbContext); } }

        public ITruckRepository Trucks { get { return new TruckRepository(DbContext); } }

        public IAccountTypeRepository AccountTypes { get { return new AccountTypeRepository(DbContext); } }

        public IAccountRepository Accounts { get { return new AccountRepository(DbContext); } }

        public IEmailLogRepository EmailLogs { get { return new EmailLogRepository(DbContext); } }

        public IRecalculationLogRepository RecalculationLogs { get { return new RecalculationLogRepository(DbContext); } }

        public IGeneralJournalRepository GeneralJournals { get { return new GeneralJournalRepository(DbContext); } }

        public IGeneralJournalDetailRepository GeneralJournalDetails { get { return new GeneralJournalDetailRepository(DbContext); } }

        public ITempGeneralJournalRepository TempGeneralJournals { get { return new TempGeneralJournalRepository(DbContext); } }

        public IItemCategoryRepository ItemCategories { get { return new ItemCategoryRepository(DbContext); } }

        public ISystemSettingRepository SystemSettings { get { return new SystemSettingRepository(DbContext); } }

        public ITransferFundRepository TransferFunds { get { return new TransferFundRepository(DbContext); } }

        public ITransactionRepository Transactions { get { return new TransactionRepository(DbContext); } }

        public ITransactionDetailRepository TransactionDetails { get { return new TransactionDetailRepository(DbContext); } }

        public ISourceDocTypeRepository SourceDocTypes { get { return new SourceDocTypeRepository(DbContext); } }

        public IItemStorageRepository ItemStorages { get { return new ItemStorageRepository(DbContext); } }

        public ITimesheetRepository Timesheets { get { return new TimesheetRepository(DbContext); } }

        public ISalesRepository Sales { get { return new SalesRepository(DbContext); } }

        public IDeleteLogRepository DeleteLogs { get { return new DeleteLogRepository(DbContext); } }

        public ICompanyRepository Companies { get { return new CompanyRepository(DbContext); } }
    }
}

