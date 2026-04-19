using KLS.Contract.Services;
using KLS.Models;
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

        IDeliverScheduleRepository DeliverSchedules { get; }

        IVendorRepository Vendors { get; }

        IVendorPaymentRepository VendorPayments { get; }

        ITermRepository Terms { get; }

        ITruckRepository Trucks { get; }

        IAccountTypeRepository AccountTypes { get; }

        IAccountCategoryRepository AccountCategories { get; }

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

        IEmpAdvanceRepository EmpAdvances { get; }

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

        ICustomerPaymentDetailRepository CustomerPaymentDetails { get; }

        ICustomerPaymentSourceUseRepository CustomerPaymentSourceUses { get; }

        IItemRepository Items { get; }

        IIncomingPaymentRepository IncomingPayments { get; }

        IPurchaseOrderRepository PurchaseOrders { get; }

        IPurchaseRepository Purchases { get; }

        ITempSalesRepository TempSales { get; }

        ITempBombSalesRepository TempBombSales { get; }

        ITempPurchaseRepository TempPurchases { get; }

        IItemQuoteRepository ItemQuotes { get; }

        ITempItemQuoteRepository TempItemQuotes { get; }

        IItemHistoryRepository ItemHistories { get; }

        IPurchaseStageRepository PurchaseStages { get; }

        ISalesStageRepository SalesStages { get; }

        ITempVendorPaymentRepository TempVendorPayments { get; }

        IDocumentTemplateRepository DocumentTemplates { get; }

        IItemImageRepository ItemImages { get; }

        IInventoryAdjRepository InventoryAdjs { get; }

        ITempInventoryAdjRepository TempInventoryAdjs { get; }

        ITempTransferFundRepository TempTransferFunds { get; }

        ITempCustomerPaymentRepository TempCustomerPayments { get; }

        ITempExtraPaymentRepository TempExtraPayments { get; }

        IInventoryAdjDetailRepository InventoryAdjDetails { get; }

        IUserAccountRepository UserAccounts { get; }

        IUserRoleRepository UserRoles { get; }

        IItemTagRepository ItemTags { get; }

        IItemUnitRepository ItemUnits { get; }

        IItemNameDetailRepository ItemNameDetails { get; }

        IUserLogRepository UserLogs { get; }

        ISalesRouteRepository SalesRoutes { get; }

        ISalesRouteDetailRepository SalesRouteDetails { get; }

        IPrintLogRepository PrintLogs { get; }

        IReportRepository Reports { get; }

        ILiabilityRepository Liabilities { get; }

        ICheckTrackerRepository CheckTrackers { get; }

        IPaymentMethodRepository PaymentMethods { get; }

        IPaymentGatewayRepository PaymentGateways { get; }

        IShipmentRepository Shipments { get; }

        IShipmentChargeRepository ShipmentCharges { get; }

        IShipmentPurchaseRepository ShipmentPurchases { get; }

        IItemTariffRepository ItemTariffs { get; }

        ICountryRepository Countries { get; }

        IPromotionRepository Promotions { get; }

        IPromotionItemRepository PromotionItems { get; }

        IPromotionCategoryRepository PromotionCategories { get; }

        IPromotionBogoRepository PromotionBogos { get; }

        IPromotionScheduleRepository PromotionSchedules { get; }

        ITempSalesPromoRepository TempSalesPromos { get; }

        IRest365Repository Rest365 { get; }

        IRest365DetailRepository Rest365Details { get; }

        ISchedulerConfigRepository SchedulerConfigs { get; }

        IPermissionRepository Permissions { get; }

        IRolePermissionRepository RolePermissions { get; }

        // Marketplace
        IMarketAccountRepository MarketAccounts { get; }
        IMarketItemMapRepository MarketItemMaps { get; }
        IMarketOrderRepository MarketOrders { get; }
        IMarketOrderItemRepository MarketOrderItems { get; }
        IMarketSyncLogRepository MarketSyncLogs { get; }

        void Commit();
        void ExecuteInTransaction(Action action);
    }
}
