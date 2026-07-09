using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class CompanyService : BaseService, ICompanyService
    {
        private readonly IWebHostEnvironment _env;

        public CompanyService(IUnitOfWork uow, IWebHostEnvironment env) : base(uow)
        {
            _env = env;
        }

        public Company GetDefault()
        {
            var company = Uow.Companies.GetAll().FirstOrDefault();

            if (company != null)
            {
                company.NextWorkingDate = GetNextWorkDate();

                // Populate the PDF logo as a base64 data URI (reliable for IronPdf's
                // Chrome renderer -- no file-path/BaseUrl dependency). Done here, not in
                // the entity ctor, because HasLogo isn't materialized until after the ctor.
                if (company.HasLogo)
                {
                    var logoPath = Path.Combine(_env.WebRootPath, "Logo", "logo.png");
                    if (File.Exists(logoPath))
                        company.LogoUrl = "data:image/png;base64," + Convert.ToBase64String(File.ReadAllBytes(logoPath));
                }
            }

            return company;
        }

        public CompanySeo? GetSeo()
        {
            return Uow.CompanySeos.GetAll().FirstOrDefault();
        }

        public DateOnly GetNextWorkDate()
        {
            return Uow.Companies.GetNextWorkDate();
        }
    }
}
