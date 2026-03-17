using KLS.Common;
using KLS.Models;
using KLS.Models.Reports;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Data.DataContext
{
    public class KLSDBContext : DbContext
    {
        public KLSDBContext()
        {
            Database.SetCommandTimeout(600);
        }

        protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
        {
            if (!optionsBuilder.IsConfigured)
            {
                var connectionString = Constants.ConnectionString;
                optionsBuilder.UseSqlServer(connectionString);
            }
        }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<Holiday>().ToTable("Holiday");
            modelBuilder.Entity<SystemRole>().ToTable("SystemRole");
            modelBuilder.Entity<SystemUser>().ToTable("SystemUser");
            modelBuilder.Entity<Employee>().ToTable("Employee");
            modelBuilder.Entity<EmailSetting>().ToTable("EmailSetting");
            modelBuilder.Entity<Customer>().ToTable("Customer");
            modelBuilder.Entity<Vendor>().ToTable("Vendor");
            modelBuilder.Entity<Term>().ToTable("Term");
            modelBuilder.Entity<Truck>().ToTable("Truck");
            modelBuilder.Entity<AccountType>().ToTable("AccountType");
            modelBuilder.Entity<AccountCategory>().ToTable("AccountCategory");
            modelBuilder.Entity<Account>().ToTable("Account");
            modelBuilder.Entity<EmailLog>().ToTable("EmailLog");
            modelBuilder.Entity<RecalculationLog>().ToTable("RecalculationLog");
            modelBuilder.Entity<GeneralJournal>().ToTable("GeneralJournal");
            modelBuilder.Entity<GeneralJournalDetail>().ToTable("GeneralJournalDetail");
            modelBuilder.Entity<TempGeneralJournal>().ToTable("TempGeneralJournal");
            modelBuilder.Entity<ItemCategory>().ToTable("ItemCategory");
            modelBuilder.Entity<SystemSetting>().ToTable("SystemSetting");
            modelBuilder.Entity<TransferFund>().ToTable("TransferFund");
            modelBuilder.Entity<Transaction>().ToTable("TransactionJournal");
            modelBuilder.Entity<TransactionDetail>().ToTable("TransactionJournalDetail");
            modelBuilder.Entity<SourceDocType>().ToTable("SourceDocType");
            modelBuilder.Entity<ItemStorage>().ToTable("ItemStorage");
            modelBuilder.Entity<Sales>().ToTable("Sales");
            modelBuilder.Entity<DeleteLog>().ToTable("DeleteLog");
            modelBuilder.Entity<Company>().ToTable("Company");
            modelBuilder.Entity<BankRecon>().ToTable("BankRecon");
            modelBuilder.Entity<VendorPayment>().ToTable("VendorPayment");
            modelBuilder.Entity<PaymentOption>().ToTable("PaymentOption");
            modelBuilder.Entity<Timesheet>().ToTable("Timesheet");
            modelBuilder.Entity<TimesheetDetail>().ToTable("TimesheetDetail");
            modelBuilder.Entity<TempTimesheet>().ToTable("TempTimesheet");
            modelBuilder.Entity<PayrollService>().ToTable("PayrollService");
            modelBuilder.Entity<PayrollServiceDetail>().ToTable("PayrollServiceDetail");
            modelBuilder.Entity<PayrollServiceType>().ToTable("PayrollServiceType");
            modelBuilder.Entity<TempPayrollService>().ToTable("TempPayrollService");
            modelBuilder.Entity<PayrollDetail>().ToTable("PayrollDetail");
            modelBuilder.Entity<TempPayrollDetail>().ToTable("TempPayrollDetail");
            modelBuilder.Entity<Item>().ToTable("Item");
            modelBuilder.Entity<PurchaseOrder>().ToTable("PurchaseOrder");
            modelBuilder.Entity<Purchase>().ToTable("Purchase");
            modelBuilder.Entity<TempSales>().ToTable("TempSales", tb => tb.HasTrigger("TRG_Insert_TempSalesSetLineId"));
            modelBuilder.Entity<TempPurchase>().ToTable("TempPurchase", tb => tb.HasTrigger("TRG_Insert_TempPurchaseSetLineId"));
            modelBuilder.Entity<ItemQuote>().ToTable("ItemQuote");
            modelBuilder.Entity<TempItemQuote>().ToTable("TempItemQuote");
            modelBuilder.Entity<PurchaseStage>().ToTable("PurchaseStage");
            modelBuilder.Entity<SalesStage>().ToTable("SalesStage");
            modelBuilder.Entity<TempVendorPayment>().ToTable("TempVendorPayment");
            modelBuilder.Entity<DocumentTemplate>().ToTable("DocumentTemplate");
            modelBuilder.Entity<InventoryAdj>().ToTable("InventoryAdj");
            modelBuilder.Entity<InventoryAdjDetail>().ToTable("InventoryAdjDetail");
            modelBuilder.Entity<TempInventoryAdj>().ToTable("TempInventoryAdj");
            modelBuilder.Entity<TempTransferFund>().ToTable("TempTransferFund");
            modelBuilder.Entity<UserAccount>().ToTable("UserAccount");
            modelBuilder.Entity<UserRole>().ToTable("UserRole");
            modelBuilder.Entity<ItemTag>().ToTable("ItemTag");
            modelBuilder.Entity<ItemUnit>().ToTable("ItemUnit");
            modelBuilder.Entity<ItemNameDetail>().ToTable("ItemNameDetail");
            modelBuilder.Entity<UserLog>().ToTable("UserLog");
            modelBuilder.Entity<TempBombSales>().ToTable("TempBombSales");
            modelBuilder.Entity<SalesRoute>().ToTable("SalesRoute");
            modelBuilder.Entity<SalesRouteDetail>().ToTable("SalesRouteDetail");
            modelBuilder.Entity<PrintLog>().ToTable("PrintLog");
            modelBuilder.Entity<CustomerPayment>().ToTable("CustomerPayment");
            modelBuilder.Entity<CustomerPaymentDetail>().ToTable("CustomerPaymentDetail");
            modelBuilder.Entity<TempCustomerPayment>().ToTable("TempCustomerPayment");
            modelBuilder.Entity<TempExtraPayment>().ToTable("TempExtraPayment");
            modelBuilder.Entity<Liability>().ToTable("Liability");
            modelBuilder.Entity<CheckTracker>().ToTable("CheckTracker");
            modelBuilder.Entity<PaymentMethod>().ToTable("PaymentMethod");
            modelBuilder.Entity<PaymentGateway>().ToTable("PaymentGateway");
            modelBuilder.Entity<ItemImage>().ToTable("ItemImage");
            modelBuilder.Entity<Shipment>().ToTable("Shipment");
            modelBuilder.Entity<ShipmentCharge>().ToTable("ShipmentCharge");
            modelBuilder.Entity<ShipmentPurchase>().ToTable("ShipmentPurchase");
            modelBuilder.Entity<ItemTariff>().ToTable("ItemTariff");
            modelBuilder.Entity<Promotion>().ToTable("Promotion");
            modelBuilder.Entity<PromotionItem>().ToTable("PromotionItem");
            modelBuilder.Entity<PromotionCategory>().ToTable("PromotionCategory");
            modelBuilder.Entity<PromotionBogo>().ToTable("PromotionBogo");
            modelBuilder.Entity<Rest365>().ToTable("Rest365");
            modelBuilder.Entity<Rest365Detail>().ToTable("Rest365Detail");
            modelBuilder.Entity<PromotionSchedule>().ToTable("PromotionSchedule");
            modelBuilder.Entity<SchedulerConfig>().ToTable("SchedulerConfig");
            modelBuilder.Entity<TempSalesPromo>().ToTable("TempSalesPromo");

            modelBuilder.Entity<Country>().ToTable("Country");
            modelBuilder.Entity<Country>().Property(c => c.CountryCode).ValueGeneratedNever();

            modelBuilder.Entity<EmpJob>().ToTable("EmpJob");
            modelBuilder.Entity<EmpJob>().Property(c => c.JobCode).ValueGeneratedNever();
            modelBuilder.Entity<EmpJob>().Property(c => c.JobId).Metadata.SetAfterSaveBehavior(PropertySaveBehavior.Ignore);

            modelBuilder.Entity<Payee>().ToTable("Payee");
            modelBuilder.Entity<Payee>().Property(c => c.PayeeId).ValueGeneratedNever();
            modelBuilder.Entity<Payee>().Property(c => c.Id).Metadata.SetAfterSaveBehavior(PropertySaveBehavior.Ignore);

            modelBuilder.Entity<SalesExport>().HasNoKey();
            modelBuilder.Entity<ItemWebRowList>().HasNoKey();
        }

        #region ---DBSET---

        public DbSet<Holiday> Holidays { get; set; }

        public DbSet<SystemRole> SystemRoles { get; set; }

        public DbSet<Payee> Payees { get; set; }

        public DbSet<SystemUser> SystemUsers { get; set; }

        public DbSet<EmailSetting> EmailSettings { get; set; }

        public DbSet<Employee> Employees { get; set; }

        public DbSet<Customer> Customers { get; set; }

        public DbSet<Vendor> Vendors { get; set; }

        public DbSet<Term> Temrs { get; set; }

        public DbSet<Truck> Trucks { get; set; }

        public DbSet<AccountType> AccountTypes { get; set; }

        public DbSet<AccountCategory> AccountCategories { get; set; }

        public DbSet<Account> Accounts { get; set; }

        public DbSet<EmailLog> EmailLogs { get; set; }

        public DbSet<SchedulerConfig> SchedulerConfigs { get; set; }

        public DbSet<RecalculationLog> RecalculationLogs { get; set; }

        public DbSet<GeneralJournal> GeneralJournals { get; set; }

        public DbSet<GeneralJournalDetail> GeneralJournalDetails { get; set; }

        public DbSet<TempGeneralJournal> TempGeneralJournals { get; set; }

        public DbSet<ItemCategory> ItemCategories { get; set; }

        public DbSet<SystemSetting> SystemSettings { get; set; }

        public DbSet<TransferFund> TransferFunds { get; set; }

        public DbSet<Transaction> Transactions { get; set; }

        public DbSet<TransactionDetail> TransactionDetails { get; set; }

        public DbSet<SourceDocType> SourceDocTypes { get; set; }

        public DbSet<ItemStorage> ItemStorages { get; set; }

        public DbSet<Timesheet> Timesheets { get; set; }

        public DbSet<Sales> Sales { get; set; }

        public DbSet<DeleteLog> DeleteLogs { get; set; }

        public DbSet<Company> Companies { get; set; }

        public DbSet<BankRecon> BankRecons { get; set; }

        public DbSet<VendorPayment> VendorPayments { get; set; }

        public DbSet<PaymentOption> PaymentOptions { get; set; }

        public DbSet<PayrollService> PayrollServices { get; set; }

        public DbSet<TimesheetDetail> TimesheetDetails { get; set; }

        public DbSet<TempTimesheet> TempTimesheets { get; set; }

        public DbSet<PayrollServiceDetail> PayrollServiceDetails { get; set; }

        public DbSet<PayrollServiceType> PayrollServiceTypes { get; set; }

        public DbSet<EmpJob> EmpJobs { get; set; }

        public DbSet<TempPayrollService> TempPayrollServices { get; set; }

        public DbSet<PayrollDetail> PayrollDetails { get; set; }

        public DbSet<TempPayrollDetail> TempPayrollDetails { get; set; }

        public DbSet<Item> Items { get; set; }

        public DbSet<PurchaseOrder> PurchaseOrders { get; set; }

        public DbSet<Purchase> Purchases { get; set; }

        public DbSet<TempSales> TempSales { get; set; }

        public DbSet<TempBombSales> TempBombSales { get; set; }

        public DbSet<TempPurchase> TempPurchases { get; set; }

        public DbSet<ItemQuote> ItemQuotes { get; set; }

        public DbSet<TempItemQuote> TempItemQuotes { get; set; }

        public DbSet<PurchaseStage> PurchaseStages { get; set; }

        public DbSet<SalesStage> SalesStages { get; set; }

        public DbSet<TempVendorPayment> TempVendorPayments { get; set; }

        public DbSet<DocumentTemplate> DocumentTemplates { get; set; }

        public DbSet<InventoryAdj> InventoryAdjs { get; set; }

        public DbSet<InventoryAdjDetail> InventoryAdjDetails { get; set; }

        public DbSet<TempInventoryAdj> TempInventoryAdjs { get; set; }

        public DbSet<TempTransferFund> TempTransferFunds { get; set; }

        public DbSet<CustomerPayment> CustomerPayments { get; set; }

        public DbSet<CustomerPaymentDetail> CustomerPaymentDetails { get; set; }

        public DbSet<TempCustomerPayment> TempCustomerPayments { get; set; }

        public DbSet<TempExtraPayment> TempExtraPayments { get; set; }

        public DbSet<UserAccount> UserAccounts { get; set; }

        public DbSet<UserRole> UserRoles { get; set; }

        public DbSet<ItemTag> ItemTags { get; set; }

        public DbSet<ItemUnit> ItemUnits { get; set; }

        public DbSet<ItemNameDetail> ItemNameDetails { get; set; }

        public DbSet<UserLog> UserLogs { get; set; }

        public DbSet<SalesRoute> SalesRoutes { get; set; }

        public DbSet<SalesRouteDetail> SalesRouteDetails { get; set; }

        public DbSet<PrintLog> PrintLogs { get; set; }

        public DbSet<Liability> Liabilities { get; set; }

        public DbSet<CheckTracker> CheckTrackers { get; set; }

        public DbSet<PaymentMethod> PaymentMethods { get; set; }

        public DbSet<PaymentGateway> PaymentGateways { get; set; }

        public DbSet<ItemImage> ItemImages { get; set; }

        public DbSet<Shipment> Shipments { get; set; }

        public DbSet<ShipmentCharge> ShipmentCharges { get; set; }

        public DbSet<ShipmentPurchase> ShipmentPurchases { get; set; }

        public DbSet<ItemTariff> ItemTariffs { get; set; }

        public DbSet<Country> Countries { get; set; }

        public DbSet<Promotion> Promotions { get; set; }

        public DbSet<PromotionItem> PromotionItems { get; set; }

        public DbSet<PromotionCategory> PromotionCategories { get; set; }

        public DbSet<PromotionBogo> PromotionBogos { get; set; }

        public DbSet<PromotionSchedule> PromotionSchedules { get; set; }

        public DbSet<TempSalesPromo> TempSalesPromos { get; set; }

        public DbSet<Rest365> Rest365 { get; set; }

        public DbSet<Rest365Detail> Rest365Details { get; set; }

        #endregion

        #region ---Virtual DBSET---

        public virtual DbSet<EmailLogDTO> EmailLogDTO { get; set; }

        public virtual DbSet<AccountDTO> AccountDTO { get; set; }

        public virtual DbSet<CreditDebitAmount> CreditDebitAmount { get; set; }

        public virtual DbSet<TempGeneralJournalList> TempGeneralJournalList { get; set; }

        public virtual DbSet<TransferFundList> TransferFundList { get; set; }

        public virtual DbSet<DepositList> DepositList { get; set; }

        public virtual DbSet<EmployeeList> EmployeeList { get; set; }

        public virtual DbSet<PayeeSearch> PayeeSearch { get; set; }

        public virtual DbSet<VendorSearchDTO> VendorSearchDTO { get; set; }

        public virtual DbSet<CheckRegister> CheckRegister { get; set; }

        public virtual DbSet<EmpAdvance> EmpAdvance { get; set; }

        public virtual DbSet<PayrollServiceDTO> PayrollServiceDTO { get; set; }

        public virtual DbSet<VendorPaymentList> VendorPaymentList { get; set; }

        public virtual DbSet<PayrollList> PayrollList { get; set; }

        public virtual DbSet<CheckInOut> CheckInOut { get; set; }

        public virtual DbSet<CustomerPaymentList> CustomerPaymentList { get; set; }

        public virtual DbSet<IncomingPaymentList> IncomingPaymentList { get; set; }

        public virtual DbSet<PurchaseOrderList> PurchaseOrderList { get; set; }

        public virtual DbSet<SalesList> SalesList { get; set; }

        public virtual DbSet<PurchaseList> PurchaseList { get; set; }

        public virtual DbSet<VendorList> VendorList { get; set; }

        public virtual DbSet<TransactionDetailList> TransactionDetailList { get; set; }

        public virtual DbSet<CustomerList> CustomerList { get; set; }

        public virtual DbSet<ItemSearch> ItemSearch { get; set; }

        public virtual DbSet<ItemList> ItemList { get; set; }

        public virtual DbSet<ARCustomerList> ARCustomerList { get; set; }

        public virtual DbSet<TempPurchaseItem> TempPurchaseItem { get; set; }

        public virtual DbSet<ItemHistorySales> ItemHistorySales { get; set; }

        public virtual DbSet<ItemHistoryPurchase> ItemHistoryPurchase { get; set; }

        public virtual DbSet<ItemHistoryInventory> ItemHistoryInventory { get; set; }

        public virtual DbSet<ItemCalcUnit> ItemCalcUnit { get; set; }

        public virtual DbSet<ItemPrice> ItemPrice { get; set; }

        public virtual DbSet<ItemDefaultFreight> ItemDefaultFreight { get; set; }

        public virtual DbSet<PODetail> PODetail { get; set; }

        public virtual DbSet<InventoryAdjList> InventoryAdjList { get; set; }

        public virtual DbSet<InventoryClosingDetail> InventoryClosingDetail { get; set; }

        public virtual DbSet<TempInventoryItem> TempInventoryItem { get; set; }

        public virtual DbSet<TempDepositList> TempDepositList { get; set; }

        public virtual DbSet<TempSalesItem> TempSalesItem { get; set; }

        public virtual DbSet<BombSalesItem> BombSalesItem { get; set; }

        public virtual DbSet<TempItemQuoteList> TempItemQuoteList { get; set; }

        public virtual DbSet<ShipRouteSummary> ShipRouteSummary { get; set; }

        public virtual DbSet<ShipRouteDetail> ShipRouteDetail { get; set; }

        public virtual DbSet<TempCustomerPaymentList> TempCustomerPaymentList { get; set; }

        public virtual DbSet<CustomerPaymentStatement> CustomerPaymentStatement { get; set; }

        public virtual DbSet<LiabilityList> LiabilityList { get; set; }

        public virtual DbSet<LiabilityTxList> LiabilityTxList { get; set; }

        public virtual DbSet<TargetQuotePrice> TargetQuotePrice { get; set; }

        public virtual DbSet<ShipmentList> ShipmentList { get; set; }

        public virtual DbSet<AssignedShipmentRow> AssignedShipmentRow { get; set; }

        public virtual DbSet<AssignedPurchase> AssignedPurchase { get; set; }

        public virtual DbSet<ItemTariffList> ItemTariffList { get; set; }

        public virtual DbSet<PromotionList> PromotionList { get; set; }

        public virtual DbSet<PayeeExport> PayeeExport { get; set; }

        public virtual DbSet<SalesExport> SalesExport { get; set; }

        #endregion

        #region ---Report DBSET---

        public virtual DbSet<Invoice> Invoice { get; set; }

        public virtual DbSet<InvoiceDetail> InvoiceDetail { get; set; }

        public virtual DbSet<RptPO> RptPO { get; set; }

        public virtual DbSet<RptPODetail> RptPODetail { get; set; }

        public virtual DbSet<RptSalesTax> RptSalesTax { get; set; }

        public virtual DbSet<RptResponsibleRow> RptResponsibleRow { get; set; }

        public virtual DbSet<RptDailySummaryRow> RptDailySummaryRow { get; set; }

        public virtual DbSet<RptSalesDaily> RptSalesDaily { get; set; }

        public virtual DbSet<RptDescDollar> RptDescDollar { get; set; }



        public virtual DbSet<RptPackingItem> RptPackingItem { get; set; }

        public virtual DbSet<RptHarvillsItem> RptHarvillsItem { get; set; }

        public virtual DbSet<RptStoreTotalItem> RptStoreTotalItem { get; set; }

        public virtual DbSet<RptSensitiveItem> RptSensitiveItem { get; set; }

        public virtual DbSet<RptAssignTruck> RptAssignTruck { get; set; }

        public virtual DbSet<RptLoadingItem> RptLoadingItem { get; set; }

        public virtual DbSet<RptPackingLabel> RptPackingLabel { get; set; }


        public virtual DbSet<RptBalanceSheetRow> RptBalanceSheetRow { get; set; }

        public virtual DbSet<RptProfitLossRow> RptProfitLossRow { get; set; }

        public virtual DbSet<RptPricesheet> RptPricesheet { get; set; }

        public virtual DbSet<RptLedgerRow> RptLedgerRow { get; set; }

        public virtual DbSet<RptAccountHistory> RptAccountHistory { get; set; }

        public virtual DbSet<RptOrderGuideItem> RptOrderGuideItem { get; set; }

        public virtual DbSet<RptCustItemVolume> RptCustItemVolume { get; set; }

        public virtual DbSet<RptCustSalesByItem> RptCustSalesByItem { get; set; }

        #endregion

        public virtual DbSet<OrderWebList> OrderWebList { get; set; }

        public virtual DbSet<ItemWebRowList> ItemWebRowList { get; set; }
    }
}