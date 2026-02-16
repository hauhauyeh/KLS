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
    public class PaymentMethodService : BaseService, IPaymentMethodService
    {
        private readonly ISystemSettingService _systemSettingService;
        private readonly ISquareService _squareService;

        public PaymentMethodService(IUnitOfWork uow, ISystemSettingService systemSettingService, ISquareService squareService) : base(uow)
        {
            _systemSettingService = systemSettingService;
            _squareService = squareService;
        }

        public IEnumerable<PaymentMethodList>? GetByPayeeId(int payeeId)
        {
            var paymentMethods = Uow.PaymentMethods.Find(c => c.PayeeId == payeeId)
                .OrderByDescending(c => c.IsPrimary).AsNoTracking().ToList();

            var methods = new List<PaymentMethodList>();

            foreach (var method in paymentMethods)
            {
                var decrypt = DecryptById(method.PaymentMethodId);

                methods.Add(new PaymentMethodList
                {
                    PaymentMethodId = method.PaymentMethodId,
                    AccountType = method.AccountType,
                    FeePercent = method.FeePercent,
                    IsACH = method.IsACH,
                    IsPrimary = method.IsPrimary,
                    Last4 = method.Last4,
                    Notes = method.Notes,
                    AccountName = decrypt.AccountName,
                    ExpMonth = decrypt.ExpMonth,
                    ExpYear = decrypt.ExpYear,
                });
            }

            return methods;
        }

        public PaymentMethod GetById(int paymentMethodId)
        {
            return Uow.PaymentMethods.Find(c => c.PaymentMethodId == paymentMethodId).AsNoTracking().FirstOrDefault();
        }

        public PaymentMethod DecryptById(int paymentMethodId)
        {
            var method = GetById(paymentMethodId);

            method.AccountName = Utilities.Decrypt(method.AccountName);
            method.ExpMonth = Utilities.Decrypt(method.ExpMonth);
            method.ExpYear = Utilities.Decrypt(method.ExpYear);

            return method;
        }

        public PaymentMethod GetPrimaryMethod(int payeeId)
        {
            return Uow.PaymentMethods.Find(c => c.PayeeId == payeeId && c.IsPrimary).AsNoTracking().FirstOrDefault();
        }

        public bool Exists(PaymentMethod method)
        {
            if (method.IsACH)
            {
                return Uow.PaymentMethods.Find(c => c.PayeeId == method.PayeeId && c.IsACH == true).AsNoTracking().ToList().Any(c => Utilities.Decrypt(c.AccountNumber) == method.AccountNumber && Utilities.Decrypt(c.CVVOrRouting) == method.CVVOrRouting);
            }
            else
            {
                return Uow.PaymentMethods.Find(c => c.PayeeId == method.PayeeId && c.IsACH == false).AsNoTracking().ToList().Any(c => Utilities.Decrypt(c.AccountNumber) == method.AccountNumber);
            }
        }

        public void Create(PaymentMethod method)
        {
            string last4 = (method.AccountNumber.Length > 3) ? method.AccountNumber.Substring(method.AccountNumber.Length - 4, 4) : "";

            decimal? feePerc = null;

            if (!method.IsACH)
            {
                var defaultFee = _systemSettingService.GetByKey<decimal>(GlobalKey.DEFAULT_CCFEE_PERCENTAGE);

                feePerc = Utilities.Rounding(method.FeePercent, 4) ?? defaultFee;
            }

            var newMethod = new PaymentMethod
            {
                PayeeId = method.PayeeId,
                IsACH = method.IsACH,
                AccountType = method.AccountType,
                AccountNumber = Utilities.Encrypt(method.AccountNumber),
                AccountName = Utilities.Encrypt(method.AccountName),
                CVVOrRouting = Utilities.Encrypt(method.CVVOrRouting),
                ExpMonth = Utilities.Encrypt(method.ExpMonth),
                ExpYear = Utilities.Encrypt(method.ExpYear),
                Zipcode = Utilities.Encrypt(method.Zipcode),
                Last4 = last4,
                IsPrimary = method.IsPrimary,
                FeePercent = feePerc,
                Notes = method.Notes,
                SQNonce = Utilities.Encrypt(method.SQNonce)
            };

            var methods = Uow.PaymentMethods.Find(c => c.PayeeId == method.PayeeId && c.IsPrimary).ToList();

            if (methods.Any())
            {
                if (method.IsPrimary)
                {
                    foreach (var payment in methods)
                    {
                        payment.IsPrimary = false;
                        Uow.PaymentMethods.Update(payment);
                    }
                }
            }
            else
            {
                newMethod.IsPrimary = true;
            }

            //save card info on square
            if (!newMethod.IsACH && !string.IsNullOrEmpty(newMethod.SQNonce))
            {
                var cardResp = _squareService.CreateCard(method).Result;

                if (cardResp.Card != null)
                {
                    newMethod.SQCardId = Utilities.Encrypt(cardResp.Card.Id);
                    newMethod.SQCustId = Utilities.Encrypt(cardResp.Card.CustomerId);
                    newMethod.ExpMonth = Utilities.Encrypt(cardResp.Card.ExpMonth.ToString());
                    newMethod.ExpYear = Utilities.Encrypt(cardResp.Card.ExpYear.ToString());
                    newMethod.AccountType = cardResp.Card.CardBrand.ToString();
                    newMethod.AccountName = Utilities.Encrypt(cardResp.Card.CardholderName);
                }
            }

            Uow.PaymentMethods.Add(newMethod);
            Uow.Commit();
        }

        public void Delete(int paymentMethodId)
        {
            Uow.PaymentMethods.RemoveById(paymentMethodId);
            Uow.Commit();
        }

        public void SetPrimary(int paymentMethodId)
        {
            var method = Uow.PaymentMethods.GetById(paymentMethodId);

            var methods = Uow.PaymentMethods.Find(c => c.PayeeId == method.PayeeId && c.IsPrimary).ToList();

            foreach (var item in methods)
            {
                item.IsPrimary = false;
                Uow.PaymentMethods.Update(item);
            }

            method.IsPrimary = true;

            Uow.PaymentMethods.Update(method);
            Uow.Commit();
        }
    }
}
