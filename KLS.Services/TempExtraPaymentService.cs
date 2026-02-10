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
    public class TempExtraPaymentService : BaseService, ITempExtraPaymentService
    {
        public TempExtraPaymentService(IUnitOfWork uow) : base(uow)
        {
        }

        public IEnumerable<TempExtraPayment> Create(TempExtraPayment extraPayment)
        {
            Clear(extraPayment);

            extraPayment.EmpId = UserContext.EmpId;

            Uow.TempExtraPayments.Add(extraPayment);
            Uow.Commit();

            var extraPayments = Uow.TempExtraPayments.Find(c => c.EmpId == UserContext.EmpId && c.CustomerPaymentId == extraPayment.CustomerPaymentId).ToList();

            foreach (var payment in extraPayments)
            {
                payment.PayeeName = Uow.Payees.GetById(payment.PayeeId)?.PayeeName;
            }

            return extraPayments;
        }

        public void Update(TempExtraPayment extraPayment)
        {
            var existing = Uow.TempExtraPayments.GetById(extraPayment.TempExtraPaymentId);

            if (existing != null)
            {
                existing.AsCredit = extraPayment.AsCredit;
                existing.AsIncome = extraPayment.AsIncome;

                Uow.TempExtraPayments.Update(existing);
                Uow.Commit();
            }
        }

        public void Clear(TempExtraPayment extraPayment)
        {
            Uow.TempExtraPayments.Find(c => c.EmpId == UserContext.EmpId && c.CustomerPaymentId == extraPayment.CustomerPaymentId).ExecuteDelete();
        }
    }
}
