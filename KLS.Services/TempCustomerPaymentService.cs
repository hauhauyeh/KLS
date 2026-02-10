using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class TempCustomerPaymentService : BaseService, ITempCustomerPaymentService
    {
        private readonly IWebHostEnvironment _env;

        public TempCustomerPaymentService(IUnitOfWork uow, IWebHostEnvironment env) : base(uow)
        {
            _env = env;
        }

        public IEnumerable<TempCustomerPaymentList>? GetList(TempPaymentReq tempPaymentReq)
        {
            var invoices = Uow.TempCustomerPayments.GetList(tempPaymentReq)?.ToList();

            foreach (var invoice in invoices)
            {
                invoice.IsPdfExist = IsInvoicePdfExist(invoice.SalesNumber);
            }

            return invoices;
        }

        public TempCustomerPayment GetById(int tempId)
        {
            return Uow.TempCustomerPayments.GetById(tempId);
        }

        public TempCustomerPaymentList GetListById(TempCustomerPayment tempPayment)
        {
            var paymentReq = new TempPaymentReq
            {
                PayeeId = tempPayment.PayeeId,
                PaymentId = tempPayment.CustomerPaymentId,
                TempId = tempPayment.TempCPId
            };

            return GetList(paymentReq).FirstOrDefault();
        }

        public IEnumerable<TempCustomerPaymentList>? Inject(TempPaymentReq tempPaymentReq)
        {
            Uow.TempCustomerPayments.Inject(tempPaymentReq);

            return GetList(tempPaymentReq);
        }

        public TempCustomerPaymentList Create(TempPaymentReq tempPaymentReq)
        {
            var newTempId = Uow.TempCustomerPayments.InsertInvoice(tempPaymentReq);

            tempPaymentReq.TempId = newTempId;

            return GetList(tempPaymentReq).FirstOrDefault();
        }

        public TempCustomerPaymentList Update(TempCustomerPayment tempCustomerPayment)
        {
            var tempCustomerPmt = GetById(tempCustomerPayment.TempCPId);

            if (tempCustomerPmt != null)
            {
                tempCustomerPmt.IsApplied = tempCustomerPayment.IsApplied;
                tempCustomerPmt.PaymentApplied = tempCustomerPayment.PaymentApplied;
                tempCustomerPmt.PaymentDiscount = tempCustomerPayment.PaymentDiscount;
                tempCustomerPmt.ShortDiscount = tempCustomerPayment.ShortDiscount;

                Uow.TempCustomerPayments.Update(tempCustomerPmt);
                Uow.Commit();
            }

            return GetListById(tempCustomerPmt);
        }

        public void Clear(int payeeId)
        {
            Uow.TempCustomerPayments.Find(c => c.EmpId == UserContext.EmpId && c.PayeeId == payeeId).ExecuteDelete();
        }

        public void Delete(int tempId)
        {
            Uow.TempCustomerPayments.RemoveById(tempId);
            Uow.Commit();
        }

        private bool IsInvoicePdfExist(int salesNumber)
        {
            // Get absolute path to wwwroot/InvoicePdf
            var pdfFile = Path.Combine(_env.WebRootPath, "InvoicePdf", salesNumber + ".pdf");

            return File.Exists(pdfFile);
        }
    }
}
