using KLS.Contract.Interfaces;
using KLS.Services.Interfaces;
using KLS.Services;
using Microsoft.AspNetCore.Cors.Infrastructure;
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

            return services;
        }
    }
}
