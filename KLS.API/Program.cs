using KLS.API.Helpers;
using KLS.Common;
using KLS.Services;
using KLS.Services.Interfaces;
using Microsoft.OpenApi.Models;

var builder = WebApplication.CreateBuilder(args);

Constants.ConnectionString = builder.Configuration.GetValue<string>("ConnectionStrings:Default");

// Register services
builder.Services.Configure<AppSettings>(builder.Configuration.GetSection("AppSettings"));
builder.Services.AddHttpClient();
builder.Services.AddHttpContextAccessor();

builder.Services.AddApplicationServices();

builder.Services.AddSingleton<DateTimeMiddleware>();
builder.Services.AddSingleton<IJWTService, JWTService>();
//builder.Services.AddScoped<ModelValidationAttribute>();

builder.Services.AddCors(options =>
{
    options.AddPolicy("corsapp", policy =>
    {
        policy.SetIsOriginAllowed(_ => true)
              .AllowAnyMethod()
              .AllowAnyHeader()
              .AllowCredentials();
    });
});

builder.Services.AddControllers().AddJsonOptions(options =>
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


var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

app.UseRouting();                      // Always first after redirection

app.UseCors("corsapp");               // Before Auth and Middleware

app.UseAuthentication();              // Before custom middleware

app.UseMiddleware<JWTMiddleware>();   // Custom token logic here

app.UseAuthorization();               // After auth

app.UseStaticFiles();

app.MapControllers();


app.Run();
