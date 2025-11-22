using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
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

        public IEnumerable<Company> GetDefault()
        {
            return Uow.Companies.GetAll().ToList();
        }
    }
}
