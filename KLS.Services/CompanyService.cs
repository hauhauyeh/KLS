using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class CompanyService : BaseService, ICompanyService
    {
        public CompanyService(IUnitOfWork uow) : base(uow)
        {

        }

        public Company GetDefault()
        {
            var company = Uow.Companies.GetAll().FirstOrDefault();

            if (company != null)
            {
                company.NextWorkingDate = GetNextWorkDate();
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
