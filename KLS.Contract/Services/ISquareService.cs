using KLS.Models;
using Square;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ISquareService
    {
        Task<CreateCardResponse> CreateCard(PaymentMethod paymentMethod);

        Task<CreatePaymentResponse> ChargePayment(int payeeId, string squareCustomerId, string squareCardId, long amount);
    }
}
