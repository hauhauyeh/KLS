using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Square;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class PaymentGatewayService : BaseService, IPaymentGatewayService
    {
        public PaymentGatewayService(IUnitOfWork uow) : base(uow)
        {
        }

        public PaymentGateway GetByCode(string code)
        {
            return Uow.PaymentGateways.Find(c => c.GatewayCode == code).FirstOrDefault();
        }

        public SquareInfo GetSQInfo()
        {
            var gateway = Uow.PaymentGateways.Find(c => c.GatewayCode == "SQUARE" && c.IsActive)?.FirstOrDefault();

            if (gateway == null)
                return null;

            return new SquareInfo
            {
                AppId = gateway.ClientKey,
                LocationId = gateway.MerchantId,
                Environment = gateway.Environment
            };
        }
    }
}
