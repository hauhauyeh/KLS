using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Data.Repositories;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Data.Repositories
{
    public class PaymentOptionRepository : KLSRepository<PaymentOption>, IPaymentOptionRepository
    {
        public PaymentOptionRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }
    }
}