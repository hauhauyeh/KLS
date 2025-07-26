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
            services.AddScoped<IUserRoleService, UserRoleService>();
            services.AddScoped<ISystemSettingService, SystemSettingService>();
            services.AddScoped<IUserService, UserService>();

            services.AddScoped<IHolidayService, HolidayService>();
            services.AddScoped<IPayeeService, PayeeService>();
            services.AddScoped<IEmployeeService, EmployeeService>();
            services.AddScoped<ITermService, TermService>();
            services.AddScoped<ITruckService, TruckService>();
            services.AddScoped<IVendorService, VendorService>();
            services.AddScoped<IChartOfAccountService, ChartOfAccountService>();
            services.AddScoped<IChartOfAccountTypeService, ChartOfAccountTypeService>();
            services.AddScoped<IEmailLogService, EmailLogService>();
            services.AddScoped<IRecalculationLogService, RecalculationLogService>();

            return services;
        }
    }
}
