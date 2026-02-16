using KLS.Models;
using Square;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface IMxMerchantService
    {
        Task<MxCreatePaymentResponse> ChargeAsync(PaymentMethod paymentMethod, decimal amount, bool isDecrypt,
        CancellationToken ct = default);
    }
}
