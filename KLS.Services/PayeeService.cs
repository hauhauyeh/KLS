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
    public class PayeeService : BaseService, IPayeeService
    {
        public PayeeService(IUnitOfWork uow) : base(uow)
        {
        }

        public ICollection<PayeeSearch>? SearchPayee(PayeeSearchReq searchReq)
        {
            return Uow.Payees.SearchPayee(searchReq)?.ToList();
        }
    }
}
