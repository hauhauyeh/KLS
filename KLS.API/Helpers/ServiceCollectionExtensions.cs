using KLS.Contract.Interfaces;
using KLS.Services.Interfaces;
using KLS.Services;
using KLS.Data.Repositories;

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
            services.AddScoped<IEmployeeAdvancePmtService, EmployeeAdvancePmtService>();
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
            services.AddScoped<ICustomerService, CustomerService>();
            services.AddScoped<IItemQuoteService, ItemQuoteService>();
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
            services.AddScoped<IUnitService, UnitService>();
            services.AddScoped<IItemTagService, ItemTagService>();
            services.AddScoped<IItemNameDetailService, ItemNameDetailService>();
            services.AddScoped<IPDFService, PDFService>();

            return services;
        }
    }
}
