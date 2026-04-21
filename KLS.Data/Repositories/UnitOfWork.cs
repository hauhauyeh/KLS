using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using Microsoft.EntityFrameworkCore.Storage;
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

        public void ExecuteInTransaction(Action action)
        {
            using IDbContextTransaction transaction = DbContext.Database.BeginTransaction();

            try
            {
                action();
                transaction.Commit();
            }
            catch
            {
                transaction.Rollback();
                throw;
            }
        }

        public IHolidayRepository Holidays { get { return new HolidayRepository(DbContext); } }

        public ISystemRoleRepository SystemRoles { get { return new SystemRoleRepository(DbContext); } }

        public IPayeeRepository Payees { get { return new PayeeRepository(DbContext); } }

        public ISystemUserRepository SystemUsers { get { return new SystemUserRepository(DbContext); } }

        public IEmployeeRepository Employees { get { return new EmployeeRepository(DbContext); } }

        public IEmailSettingRepository EmailSettings { get { return new EmailSettingRepository(DbContext); } }

        public ICustomerRepository Customers { get { return new CustomerRepository(DbContext); } }

        public IDeliverScheduleRepository DeliverSchedules { get { return new DeliverScheduleRepository(DbContext); } }

        public IVendorRepository Vendors { get { return new VendorRepository(DbContext); } }

        public ITermRepository Terms { get { return new TermRepository(DbContext); } }

        public ITruckRepository Trucks { get { return new TruckRepository(DbContext); } }

        public IAccountTypeRepository AccountTypes { get { return new AccountTypeRepository(DbContext); } }

        public IAccountCategoryRepository AccountCategories { get { return new AccountCategoryRepository(DbContext); } }

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

        public IBankReconRepository BankRecons { get { return new BankReconRepository(DbContext); } }

        public IVendorPaymentRepository VendorPayments { get { return new VendorPaymentRepository(DbContext); } }

        public IPaymentOptionRepository PaymentOptions { get { return new PaymentOptionRepository(DbContext); } }

        public IEmpAdvanceRepository EmpAdvances { get { return new EmpAdvanceRepository(DbContext); } }

        public IPayrollServiceRepository PayrollServices { get { return new PayrollServiceRepository(DbContext); } }

        public ITimesheetDetailRepository TimesheetDetails { get { return new TimesheetDetailRepository(DbContext); } }

        public ITempTimesheetRepository TempTimesheets { get { return new TempTimesheetRepository(DbContext); } }

        public IPayrollServiceDetailRepository PayrollServiceDetails { get { return new PayrollServiceDetailRepository(DbContext); } }

        public IPayrollServiceTypeRepository PayrollServiceTypes { get { return new PayrollServiceTypeRepository(DbContext); } }

        public IEmpJobRepository EmpJobs { get { return new EmpJobRepository(DbContext); } }

        public ITempPayrollServiceRepository TempPayrollServices { get { return new TempPayrollServiceRepository(DbContext); } }

        public IPayrollDetailRepository PayrollDetails { get { return new PayrollDetailRepository(DbContext); } }

        public ITempPayrollDetailRepository TempPayrollDetails { get { return new TempPayrollDetailRepository(DbContext); } }

        public IItemRepository Items { get { return new ItemRepository(DbContext); } }

        public IIncomingPaymentRepository IncomingPayments { get { return new IncomingPaymentRepository(DbContext); } }

        public IPurchaseOrderRepository PurchaseOrders { get { return new PurchaseOrderRepository(DbContext); } }

        public IPurchaseRepository Purchases { get { return new PurchaseRepository(DbContext); } }

        public ITempSalesRepository TempSales { get { return new TempSalesRepository(DbContext); } }

        public ITempBombSalesRepository TempBombSales { get { return new TempBombSalesRepository(DbContext); } }

        public ITempPurchaseRepository TempPurchases { get { return new TempPurchaseRepository(DbContext); } }

        public IItemQuoteRepository ItemQuotes { get { return new ItemQuoteRepository(DbContext); } }

        public ITempItemQuoteRepository TempItemQuotes { get { return new TempItemQuoteRepository(DbContext); } }

        public IItemHistoryRepository ItemHistories { get { return new ItemHistoryRepository(DbContext); } }

        public IPurchaseStageRepository PurchaseStages { get { return new PurchaseStageRepository(DbContext); } }

        public ISalesStageRepository SalesStages { get { return new SalesStageRepository(DbContext); } }

        public ITempVendorPaymentRepository TempVendorPayments { get { return new TempVendorPaymentRepository(DbContext); } }

        public IDocumentTemplateRepository DocumentTemplates { get { return new DocumentTemplateRepository(DbContext); } }

        public IItemImageRepository ItemImages { get { return new ItemImageRepository(DbContext); } }

        public IInventoryAdjRepository InventoryAdjs { get { return new InventoryAdjRepository(DbContext); } }

        public ITempInventoryAdjRepository TempInventoryAdjs { get { return new TempInventoryAdjRepository(DbContext); } }

        public ITempTransferFundRepository TempTransferFunds { get { return new TempTransferFundRepository(DbContext); } }

        public ICustomerPaymentRepository CustomerPayments { get { return new CustomerPaymentRepository(DbContext); } }

        public ICustomerPaymentDetailRepository CustomerPaymentDetails { get { return new CustomerPaymentDetailRepository(DbContext); } }

        public ICustomerPaymentSourceUseRepository CustomerPaymentSourceUses { get { return new CustomerPaymentSourceUseRepository(DbContext); } }

        public ITempCustomerPaymentRepository TempCustomerPayments { get { return new TempCustomerPaymentRepository(DbContext); } }

        public ITempExtraPaymentRepository TempExtraPayments { get { return new TempExtraPaymentRepository(DbContext); } }

        public IInventoryAdjDetailRepository InventoryAdjDetails { get { return new InventoryAdjDetailRepository(DbContext); } }

        public IUserAccountRepository UserAccounts { get { return new UserAccountRepository(DbContext); } }

        public IUserRoleRepository UserRoles { get { return new UserRoleRepository(DbContext); } }

        public IItemTagRepository ItemTags { get { return new ItemTagRepository(DbContext); } }

        public IItemUnitRepository ItemUnits { get { return new ItemUnitRepository(DbContext); } }

        public IItemNameDetailRepository ItemNameDetails { get { return new ItemNameDetailRepository(DbContext); } }

        public IUserLogRepository UserLogs { get { return new UserLogRepository(DbContext); } }

        public ISalesRouteRepository SalesRoutes { get { return new SalesRouteRepository(DbContext); } }

        public ISalesRouteDetailRepository SalesRouteDetails { get { return new SalesRouteDetailRepository(DbContext); } }

        public IPrintLogRepository PrintLogs { get { return new PrintLogRepository(DbContext); } }

        public ILiabilityRepository Liabilities { get { return new LiabilityRepository(DbContext); } }

        public ICheckTrackerRepository CheckTrackers { get { return new CheckTrackerRepository(DbContext); } }

        public IPaymentMethodRepository PaymentMethods { get { return new PaymentMethodRepository(DbContext); } }

        public IPaymentGatewayRepository PaymentGateways { get { return new PaymentGatewayRepository(DbContext); } }

        public IShipmentRepository Shipments { get { return new ShipmentRepository(DbContext); } }

        public IShipmentChargeRepository ShipmentCharges { get { return new ShipmentChargeRepository(DbContext); } }

        public IShipmentPurchaseRepository ShipmentPurchases { get { return new ShipmentPurchaseRepository(DbContext); } }

        public IItemTariffRepository ItemTariffs { get { return new ItemTariffRepository(DbContext); } }

        public ICountryRepository Countries { get { return new CountryRepository(DbContext); } }

        public IReportRepository Reports { get { return new ReportRepository(DbContext); } }

        public IPromotionRepository Promotions { get { return new PromotionRepository(DbContext); } }

        public IPromotionItemRepository PromotionItems { get { return new PromotionItemRepository(DbContext); } }

        public IPromotionCategoryRepository PromotionCategories { get { return new PromotionCategoryRepository(DbContext); } }

        public IPromotionBogoRepository PromotionBogos { get { return new PromotionBogoRepository(DbContext); } }

        public IPromotionScheduleRepository PromotionSchedules { get { return new PromotionScheduleRepository(DbContext); } }

        public ITempSalesPromoRepository TempSalesPromos { get { return new TempSalesPromoRepository(DbContext); } }

        public IRest365Repository Rest365 { get { return new Rest365Repository(DbContext); } }

        public IRest365DetailRepository Rest365Details { get { return new Rest365DetailRepository(DbContext); } }

        public ISchedulerConfigRepository SchedulerConfigs { get { return new SchedulerConfigRepository(DbContext); } }

        public IWarehousePCRepository WarehousePCs { get { return new WarehousePCRepository(DbContext); } }

        public ILabelPrintLogRepository LabelPrintLogs { get { return new LabelPrintLogRepository(DbContext); } }

        public IPermissionRepository Permissions { get { return new PermissionRepository(DbContext); } }

        public IRolePermissionRepository RolePermissions { get { return new RolePermissionRepository(DbContext); } }

        // Marketplace
        public IMarketAccountRepository MarketAccounts { get { return new MarketAccountRepository(DbContext); } }
        public IMarketItemMapRepository MarketItemMaps { get { return new MarketItemMapRepository(DbContext); } }
        public IMarketOrderRepository MarketOrders { get { return new MarketOrderRepository(DbContext); } }
        public IMarketOrderItemRepository MarketOrderItems { get { return new MarketOrderItemRepository(DbContext); } }
        public IMarketSyncLogRepository MarketSyncLogs { get { return new MarketSyncLogRepository(DbContext); } }
    }
}
