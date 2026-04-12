using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;

namespace KLS.Data.Repositories
{
    public class CustomerPaymentSourceUseRepository : KLSRepository<CustomerPaymentSourceUse>, ICustomerPaymentSourceUseRepository
    {
        public CustomerPaymentSourceUseRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }
    }
}
