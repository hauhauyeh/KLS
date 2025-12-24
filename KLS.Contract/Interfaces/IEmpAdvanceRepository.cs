using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface IEmpAdvanceRepository : IRepository<VendorPayment>
    {
        IQueryable<EmpAdvance> GetPagedList(EmpAdvanceReq empAdvanceReq);

        int Count(EmpAdvanceReq empAdvanceReq);

        int Save(EmpAdvance empAdvance);
    }
}