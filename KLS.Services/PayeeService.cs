using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Contract.Services;
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

        public Payee GetById(int payeeId)
        {
            return Uow.Payees.GetById(payeeId);
        }

        public ICollection<PayeeSearch>? SearchPayee(PayeeSearchReq searchReq)
        {
            return Uow.Payees.SearchPayee(searchReq)?.ToList();
        }

        public void OpenClose(int payeeId)
        {
            var payee = GetById(payeeId);

            if (payee != null)
            {
                payee.IsClosed = !payee.IsClosed;
                payee.UpdatedAt = DateTime.UtcNow;

                Uow.Payees.Update(payee);
                Uow.Commit();
            }
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
