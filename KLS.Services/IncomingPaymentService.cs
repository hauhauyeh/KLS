using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class IncomingPaymentService : BaseService, IIncomingPaymentService
    {
        private readonly IDeleteLogService _deleteLogService;

        public IncomingPaymentService(IUnitOfWork uow, IDeleteLogService deleteLogService) : base(uow)
        {
            _deleteLogService = deleteLogService;
        }

        public PagingResponse<IncomingPaymentList> GetIncomingPayment(IncomingPaymentListReq incomingPaymentReq)
        {
            var incomingPaymenList = Uow.IncomingPayments.GetIncomingPayments(incomingPaymentReq);

            var totalRecords = Uow.IncomingPayments.CountAllIncomingPayments(incomingPaymentReq);

            return new PagingResponse<IncomingPaymentList>(totalRecords, incomingPaymentReq.Pageno, incomingPaymentReq.Pagesize)
            {
                RowData = incomingPaymenList,
            };
        }

        public CustomerPayment GetById(int customerPaymentId)
        {
            return Uow.CustomerPayments.Find(c => c.CustomerPaymentId == customerPaymentId).Include(c => c.Payee).FirstOrDefault()!;
        }

        public CustomerPayment SaveIncomingPayment(IncomingPaymentReq incomingPaymentReq)
        {
            var newCustomerPaymentId = Uow.IncomingPayments.SaveIncomingPayment(incomingPaymentReq);

            return GetById(newCustomerPaymentId);
        }

        public void DeleteIncomingPayment(int customerPaymentId)
        {
            var customerPayment = GetById(customerPaymentId);

            if (customerPayment != null && !customerPayment.IsLocked)
            {
                Uow.CustomerPayments.Find(c => c.CustomerPaymentId == customerPaymentId).ExecuteDelete();

                string docType = EnumHelper.DocType.OtherIncomingPayment.ToString();

                _deleteLogService.Add(docType, customerPaymentId);
            }
        }
    }
}
