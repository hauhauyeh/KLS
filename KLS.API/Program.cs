using KLS.API.Helpers;
using KLS.Common;
using KLS.Contract.Services;
using KLS.Services;
using Microsoft.OpenApi.Models;

var builder = WebApplication.CreateBuilder(args);

// Set global connection string
Constants.ConnectionString = builder.Configuration.GetValue<string>("ConnectionStrings:Default");

// Configure strongly typed settings
builder.Services.Configure<AppSettings>(builder.Configuration.GetSection("AppSettings"));

// Add services
builder.Services.AddHttpClient();
builder.Services.AddApplicationServices();
builder.Services.AddHttpContextAccessor();
builder.Services.AddSingleton<DateTimeMiddleware>();
builder.Services.AddSingleton<IJWTService, JWTService>();

// Configure controllers and JSON options
builder.Services
    .AddControllers(options =>
{
    // Our custom binder for int?/decimal?/etc.
    options.ModelBinderProviders.Insert(0, new NullableNumericModelBinderProvider());
})
    .AddJsonOptions(options =>
{
    options.JsonSerializerOptions.PropertyNamingPolicy = null;
    options.JsonSerializerOptions.ReferenceHandler = System.Text.Json.Serialization.ReferenceHandler.IgnoreCycles;

    // Avoid using DI-resolved converters here (see above)
    options.JsonSerializerOptions.Converters.Add(new DateTimeMiddleware(new HttpContextAccessor()));
});

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "KLS API", Version = "v1" });
});

// Configure CORS
builder.Services.AddCors(options =>
{
    options.AddPolicy("corsapp", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyHeader()
              .AllowAnyMethod()
              .WithExposedHeaders("EmpId")
              .SetPreflightMaxAge(TimeSpan.FromSeconds(600));
    });
});

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();

app.UseCors("corsapp");

app.UseMiddleware<JWTMiddleware>();
app.UseMiddleware<UserContextMiddleware>();
app.UseMiddleware<ExceptionMiddleware>();
app.UseMiddleware<ApiKeyMiddleware>();

app.UseAuthentication();
app.UseAuthorization();

// Everything here runs ONCE when the app starts
using (var scope = app.Services.CreateScope())
{
    var settingService = scope.ServiceProvider.GetRequiredService<ISystemSettingService>();

    var pdfKey = settingService.GetByKey<string>(GlobalKey.IRONPDF_KEY);

    if (!string.IsNullOrEmpty(pdfKey))
    {
        IronPdf.License.LicenseKey = pdfKey;
        Console.WriteLine("IronPDF license applied.");
    }
}

app.MapControllers();

app.Run();
