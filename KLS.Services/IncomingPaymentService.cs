using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
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

        public PagingResponse<IncomingPaymentList> GetPagedList(IncomingPaymentListReq incomingPaymentReq)
        {
            var incomingPaymenList = Uow.IncomingPayments.GetPagedList(incomingPaymentReq);

            var totalRecords = Uow.IncomingPayments.Count(incomingPaymentReq);

            return new PagingResponse<IncomingPaymentList>(totalRecords, incomingPaymentReq.Pageno, incomingPaymentReq.Pagesize)
            {
                RowData = incomingPaymenList,
            };
        }

        public CustomerPayment GetById(int customerPaymentId)
        {
            return Uow.CustomerPayments.Find(c => c.CustomerPaymentId == customerPaymentId).Include(c => c.Payee).FirstOrDefault()!;
        }

        public CustomerPayment Save(IncomingPaymentReq incomingPaymentReq)
        {
            var newCustomerPaymentId = Uow.IncomingPayments.Save(incomingPaymentReq);

            return GetById(newCustomerPaymentId);
        }

        public void Delete(int customerPaymentId)
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
