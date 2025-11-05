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

        ISystemRoleRepository SystemRoles { get; }

        IPayeeRepository Payees { get; }

        ISystemUserRepository SystemUsers { get; }

        IEmployeeRepository Employees { get; }

        IEmailSettingRepository EmailSettings { get; }

        ISystemSettingRepository SystemSettings { get; }

        ICustomerRepository Customers { get; }

        IVendorRepository Vendors { get; }

        IVendorPaymentRepository VendorPayments { get; }

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

        ISalesRepository Sales { get; }

        IDeleteLogRepository DeleteLogs { get; }

        ICompanyRepository Companies { get; }

        IBankReconRepository BankRecons { get; }

        IPaymentOptionRepository PaymentOptions { get; }

        IEmployeeAdvancePmtRepository EmployeeAdvancePmts { get; }

        ITimesheetRepository Timesheets { get; }

        ITimesheetDetailRepository TimesheetDetails { get; }

        ITempTimesheetRepository TempTimesheets { get; }

        IPayrollServiceRepository PayrollServices { get; }

        IPayrollServiceDetailRepository PayrollServiceDetails { get; }

        ITempPayrollServiceRepository TempPayrollServices { get; }

        IPayrollServiceTypeRepository PayrollServiceTypes { get; }

        IEmpJobRepository EmpJobs { get; }

        IPayrollDetailRepository PayrollDetails { get; }

        ITempPayrollDetailRepository TempPayrollDetails { get; }

        ICustomerPaymentRepository CustomerPayments { get; }

        IItemRepository Items { get; }

        IIncomingPaymentRepository IncomingPayments { get; }

        IPurchaseOrderRepository PurchaseOrders { get; }

        IPurchaseRepository Purchases { get; }

        ITempSalesRepository TempSales { get; }

        ITempPurchaseRepository TempPurchases { get; }

        IItemQuoteRepository ItemQuotes { get; }

        IItemHistoryRepository ItemHistories { get; }

        void Commit();
    }
}
