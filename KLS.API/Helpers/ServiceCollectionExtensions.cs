using KLS.Contract.Interfaces;
using KLS.Services;
using KLS.Services.Marketplace.Amazon;
using KLS.Services.Marketplace.Common;
using KLS.Services.Marketplace.Ebay;
using KLS.Services.Marketplace.ShipStation;
using KLS.Services.Marketplace.Walmart;
using KLS.Data.Repositories;
using KLS.Contract.Services;

namespace KLS.API.Helpers
{
    public static class ServiceCollectionExtensions
    {
        public static IServiceCollection AddApplicationServices(this IServiceCollection services)
        {
            services.AddScoped<IUnitOfWork, UnitOfWork>();
            services.AddScoped<ISystemRoleService, SystemRoleService>();
            services.AddScoped<ISystemSettingService, SystemSettingService>();
            services.AddScoped<ISystemUserService, SystemUserService>();
            services.AddScoped<ITwilioService, TwilioService>();

            services.AddScoped<IHolidayService, HolidayService>();
            services.AddScoped<IPayeeService, PayeeService>();
            services.AddScoped<IEmployeeService, EmployeeService>();
            services.AddScoped<ITermService, TermService>();
            services.AddScoped<ITruckService, TruckService>();
            services.AddScoped<IVendorService, VendorService>();
            services.AddScoped<IAccountService, AccountService>();
            services.AddScoped<IAccountCategoryService, AccountCategoryService>();
            services.AddScoped<IAccountTypeService, AccountTypeService>();
            services.AddScoped<IEmailLogService, EmailLogService>();
            services.AddScoped<IEmailSettingService, EmailSettingService>();
            services.AddScoped<IRecalculationLogService, RecalculationLogService>();
            services.AddScoped<IGeneralJournalService, GeneralJournalService>();
            services.AddScoped<ITempGeneralJournalService, TempGeneralJournalService>();
            services.AddScoped<IItemCategoryService, ItemCategoryService>();
            services.AddScoped<ITransferFundService, TransferFundService>();
            services.AddScoped<ITransactionService, TransactionService>();
            services.AddScoped<ISourceDocTypeService, SourceDocTypeService>();
            services.AddScoped<IItemStorageService, ItemStorageService>();
            services.AddScoped<ISalesService, SalesService>();
            services.AddScoped<IDeleteLogService, DeleteLogService>();
            services.AddScoped<IBankReconService, BankReconService>();
            services.AddScoped<ICompanyService, CompanyService>();
            services.AddScoped<IVendorPaymentService, VendorPaymentService>();
            services.AddScoped<IPaymentOptionService, PaymentOptionService>();
            services.AddScoped<IEmpAdvanceService, EmpAdvanceService>();
            services.AddScoped<IPayrollServiceService, PayrollServiceService>();
            services.AddScoped<IPayrollServiceTypeService, PayrollServiceTypeService>();
            services.AddScoped<ITempPayrollServiceService, TempPayrollServiceService>();
            services.AddScoped<ITempPayrollDetailService, TempPayrollDetailService>();
            services.AddScoped<IPayrollDetailService, PayrollDetailService>();
            services.AddScoped<IEmpJobService, EmpJobService>();
            services.AddScoped<ITimesheetService, TimesheetService>();
            services.AddScoped<ITempTimesheetService, TempTimesheetService>();
            services.AddScoped<ICustomerPaymentService, CustomerPaymentService>();
            services.AddScoped<IItemService, ItemService>();
            services.AddScoped<IIncomingPaymentService, IncomingPaymentService>();
            services.AddScoped<IPurchaseOrderService, PurchaseOrderService>();
            services.AddScoped<IPurchaseService, PurchaseService>();
            services.AddScoped<ITempPurchaseService, TempPurchaseService>();
            services.AddScoped<ITempSalesService, TempSalesService>();
            services.AddScoped<ITempBombSalesService, TempBombSalesService>();
            services.AddScoped<ICustomerService, CustomerService>();
            services.AddScoped<IItemQuoteService, ItemQuoteService>();
            services.AddScoped<ITempItemQuoteService, TempItemQuoteService>();
            services.AddScoped<IItemHistoryService, ItemHistoryService>();
            services.AddScoped<ISalesStageService, SalesStageService>();
            services.AddScoped<IPurchaseStageService, PurchaseStageService>();
            services.AddScoped<ITempVendorPaymentService, TempVendorPaymentService>();
            services.AddScoped<IDocumentTemplateService, DocumentTemplateService>();
            services.AddScoped<IItemImageService, ItemImageService>();
            services.AddScoped<IInventoryAdjService, InventoryAdjService>();
            services.AddScoped<ITempInventoryAdjService, TempInventoryAdjService>();
            services.AddScoped<ITempTransferFundService, TempTransferFundService>();
            services.AddScoped<IUserAccountService, UserAccountService>();
            services.AddScoped<IUserRoleService, UserRoleService>();
            services.AddScoped<IItemTagService, ItemTagService>();
            services.AddScoped<IItemUnitService, ItemUnitService>();
            services.AddScoped<IItemNameDetailService, ItemNameDetailService>();
            services.AddScoped<IUserLogService, UserLogService>();
            services.AddScoped<ISalesRouteService, SalesRouteService>();
            services.AddScoped<ISalesRouteDetailService, SalesRouteDetailService>();
            services.AddScoped<IPrintLogService, PrintLogService>();
            services.AddScoped<ITempCustomerPaymentService, TempCustomerPaymentService>();
            services.AddScoped<ITempExtraPaymentService, TempExtraPaymentService>();
            services.AddScoped<ILiabilityService, LiabilityService>();
            services.AddScoped<ICheckTrackerService, CheckTrackerService>();
            services.AddScoped<IPaymentMethodService, PaymentMethodService>();
            services.AddScoped<IPaymentGatewayService, PaymentGatewayService>();
            services.AddScoped<IShipmentService, ShipmentService>();
            services.AddScoped<IShipmentPurchaseService, ShipmentPurchaseService>();
            services.AddScoped<IItemTariffService, ItemTariffService>();

            services.AddScoped<IReportService, ReportService>();
            services.AddScoped<IEmailService, EmailService>();
            services.AddScoped<IDocumentService, DocumentService>();
            services.AddScoped<IPDFService, PDFService>();
            services.AddScoped<ISquareService, SquareService>();
            services.AddScoped<IMxMerchantService, MxMerchantService>();
            services.AddScoped<IExportService, ExportService>();

            services.AddScoped<IPromotionService, PromotionService>();
            services.AddScoped<IPromotionItemService, PromotionItemService>();
            services.AddScoped<IPromotionCategoryService, PromotionCategoryService>();
            services.AddScoped<IPromotionBogoService, PromotionBogoService>();
            services.AddScoped<IPromoHelperService, PromoHelperService>();
            services.AddScoped<ICategoryRollupHelper, CategoryRollupHelper>();
            // Phase 2: IPromotionEvaluationService is retired — PromoHelperService
            // now handles EvaluateCart + TogglePromotion. File stays on disk as
            // reference (see promo-centralization.md).
            // services.AddScoped<IPromotionEvaluationService, PromotionEvaluationService>();
            services.AddScoped<IRest365Service, Rest365Service>();
            services.AddScoped<IRest365DetailService, Rest365DetailService>();
            services.AddScoped<ISchedulerConfigService, SchedulerConfigService>();
            services.AddScoped<IWarehousePCService, WarehousePCService>();
            services.AddScoped<ILabelPrintLogService, LabelPrintLogService>();
            services.AddScoped<IHomeService, HomeService>();
            services.AddScoped<IPermissionService, PermissionService>();
            services.AddMemoryCache();
            services.AddScoped<IPortalModeService, PortalModeService>();
            services.AddScoped<IContactService, ContactService>();

            // Marketplace Services
            services.AddScoped<IMarketAccountService, MarketAccountService>();
            services.AddScoped<IMarketItemMapService, MarketItemMapService>();
            services.AddScoped<IMarketSyncLogService, MarketSyncLogService>();
            services.AddScoped<IMarketOrderService, MarketOrderService>();

            // HttpClient factories
            services.AddHttpClient("AmazonLWA", c => { c.Timeout = TimeSpan.FromSeconds(30); });
            services.AddHttpClient("AmazonSPAPI", c => { c.Timeout = TimeSpan.FromSeconds(60); });
            services.AddHttpClient("WalmartAuth", c => { c.Timeout = TimeSpan.FromSeconds(30); });
            services.AddHttpClient("WalmartAPI", c => { c.Timeout = TimeSpan.FromSeconds(60); });
            services.AddHttpClient("EbayAuth", c => { c.Timeout = TimeSpan.FromSeconds(30); });
            services.AddHttpClient("EbayAPI", c => { c.Timeout = TimeSpan.FromSeconds(60); });
            services.AddHttpClient("ShipStation", c => { c.Timeout = TimeSpan.FromSeconds(60); });

            // Marketplace Factory
            services.AddScoped<IMarketplaceServiceFactory, MarketplaceServiceFactory>();

            // Amazon services
            services.AddScoped<KLS.Contract.Services.Marketplace.Amazon.IAmazonTokenService, AmazonTokenService>();
            services.AddScoped<KLS.Contract.Services.Marketplace.Amazon.IAmazonSpApiClient, AmazonSpApiClient>();
            services.AddScoped<KLS.Contract.Services.Marketplace.Amazon.IAmazonCatalogService, AmazonCatalogService>();
            services.AddScoped<AmazonConnectionService>();
            services.AddScoped<AmazonListingService>();
            services.AddScoped<AmazonPricingService>();
            services.AddScoped<AmazonInventoryService>();
            services.AddScoped<AmazonOrderService>();

            // Walmart services
            services.AddScoped<KLS.Contract.Services.Marketplace.Walmart.IWalmartTokenService, WalmartTokenService>();
            services.AddScoped<KLS.Contract.Services.Marketplace.Walmart.IWalmartApiClient, WalmartApiClient>();
            services.AddScoped<WalmartConnectionService>();
            services.AddScoped<WalmartListingService>();
            services.AddScoped<WalmartPricingService>();
            services.AddScoped<WalmartInventoryService>();
            services.AddScoped<WalmartOrderService>();

            // eBay services
            services.AddScoped<KLS.Contract.Services.Marketplace.Ebay.IEbayTokenService, EbayTokenService>();
            services.AddScoped<KLS.Contract.Services.Marketplace.Ebay.IEbayApiClient, EbayApiClient>();
            services.AddScoped<EbayConnectionService>();
            services.AddScoped<EbayListingService>();
            services.AddScoped<EbayPricingService>();
            services.AddScoped<EbayInventoryService>();
            services.AddScoped<EbayOrderService>();

            // ShipStation services
            services.AddScoped<KLS.Contract.Services.Marketplace.ShipStation.IShipStationApiClient, ShipStationApiClient>();
            services.AddScoped<ShipStationConnectionService>();
            services.AddScoped<ShipStationOrderService>();

            return services;
        }
    }
}
