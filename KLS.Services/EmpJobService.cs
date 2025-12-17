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
    public class EmpJobService : BaseService, IEmpJobService
    {
        public EmpJobService(IUnitOfWork uow) : base(uow)
        {

        }

        public ICollection<EmpJob> GetAllJobs()
        {
            return Uow.EmpJobs.GetAll().OrderBy(c => c.Inactive).ThenBy(c => c.JobId).ToList();
        }
    }
}
