using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface ICustomerPaymentRepository : IRepository<CustomerPayment>
    {
        IQueryable<CustomerPaymentList> GetPagedList(CustomerPaymentReq customerPaymentReq);

        int Count(CustomerPaymentReq customerPaymentReq);

        int Save(CustomerPaymentSaveReq paymentSaveReq);

        void Delete(int customerPaymentId);

        void SaveReturn(CustomerPaymentReturnReq returnReq);

        void DeleteReturn(int customerPaymentId);

        IQueryable<CustomerPaymentStatement>? Statement(int payeeId);

        int SaveGatewayPayment(CreateGatewayPaymentReq paymentReq);
    }
}
