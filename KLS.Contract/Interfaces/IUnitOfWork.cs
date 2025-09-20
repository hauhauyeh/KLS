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

        IUserAccountRepository UserAccounts { get; }

        IEmployeeRepository Employees { get; }

        IEmailSettingRepository EmailSettings { get; }

        ISystemSettingRepository SystemSettings { get; }

        ICustomerRepository Customers { get; }

        IVendorRepository Vendors { get; }

        ITermRepository Terms { get; }

        ITruckRepository Trucks { get; }

        IAccountTypeRepository AccountTypes { get; }

        IAccountRepository Accounts { get; }

        IEmailLogRepository EmailLogs { get; }

        IRecalculationLogRepository RecalculationLogs { get; }

        IGeneralJournalRepository GeneralJournals { get; }

        IGeneralJournalDetailRepository GeneralJournalDetails { get; }

        ITempGeneralJournalRepository TempGeneralJournals { get; }

        IItemCategoryRepository ItemCategories { get; }

        ITransferFundRepository TransferFunds { get; }

        ITransactionRepository Transactions { get; }

        ITransactionDetailRepository TransactionDetails { get; }

        ISourceDocTypeRepository SourceDocTypes { get; }

        IItemStorageRepository ItemStorages { get; }

        ITimesheetRepository Timesheets { get; }

        void Commit();
    }
}
