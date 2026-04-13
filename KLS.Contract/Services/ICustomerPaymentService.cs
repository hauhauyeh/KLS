using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ICustomerPaymentService
    {
        PagingResponse<CustomerPaymentList> GetPagedList(CustomerPaymentReq customerPaymentReq);

        CustomerPayment? GetById(int customerPaymentId);

        CustomerPayment? GetByIdWithInclude(int customerPaymentId);

        void Delete(int customerPaymentId);

        void UpdateNotes(CustomerPaymentUpdateReq updateReq);

        CustomerPaymentList Save(CustomerPaymentSaveReq paymentSaveReq);

        List<string> GetReturnTypes();

        void SaveReturn(CustomerPaymentReturnReq returnReq);

        void DeleteReturn(int customerPaymentId);

        IEnumerable<CustomerPaymentStatement>? Statement(int payeeId);

        IEnumerable<RefundQueueRow> GetRefundQueue();

        CustomerPaymentList IssueRefund(IssueRefundReq issueRefundReq);

        CustomerPayment ChargePayment(PaymentChargeReq chargeReq);

        decimal GetDueTotal(string salesIds);


        CustomerPaymentView? GetDetails(int paymentId);
    }
}
