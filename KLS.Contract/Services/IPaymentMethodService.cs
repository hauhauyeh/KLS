using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IPaymentMethodService
    {
        IEnumerable<PaymentMethodList>? GetByPayeeId(int payeeId);

        bool Exists(PaymentMethod method);

        void Create(PaymentMethod method);

        void Delete(int paymentMethodId);

        void SetPrimary(int paymentMethodId);
    }
}
