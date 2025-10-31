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

        #region --- Payee ---

        public ICollection<PayeeSearch>? SearchPayee(PayeeSearchReq searchReq)
        {
            return Uow.Payees.SearchPayee(searchReq)?.ToList();
        }

        #endregion


        #region --- ARCustomer ---

        public PagingResponse<ARCustomerList> GetARCustomers(ARCustomerListReq aRCustomerListReq)
        {
            var arlist = Uow.Payees.GetARCustomers(aRCustomerListReq);

            var totalRecords = Uow.Payees.CountAllARCustomer(aRCustomerListReq);

            return new PagingResponse<ARCustomerList>(totalRecords, aRCustomerListReq.Pageno, aRCustomerListReq.Pagesize)
            {
                RowData = arlist,
            };
        }

        #endregion
    }
}
