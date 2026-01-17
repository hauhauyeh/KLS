using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
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

            company.NextWorkingDate = GetNextWorkDate();

            return company;
        }

        public DateOnly GetNextWorkDate()
        {
            return Uow.Companies.GetNextWorkDate();
        }
    }
}
