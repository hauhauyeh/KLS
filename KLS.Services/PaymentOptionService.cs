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
    public class PaymentOptionService : BaseService, IPaymentOptionService
    {
        public PaymentOptionService(IUnitOfWork uow) : base(uow)
        {

        }

        public IQueryable<PaymentOption> GetAllPaymentOption()
        {
            return Uow.PaymentOptions.GetAll();
        }
    }
}
