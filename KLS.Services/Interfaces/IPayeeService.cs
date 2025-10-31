using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface IPayeeService
    {
        #region --- ARCustomer ---

        ICollection<PayeeSearch>? SearchPayee(PayeeSearchReq searchReq);

        #endregion

        #region --- ARCustomer ---

        PagingResponse<ARCustomerList> GetARCustomers(ARCustomerListReq aRCustomerListReq);

        #endregion
    }
}
