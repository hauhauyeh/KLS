using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ITempExtraPaymentService
    {
        IEnumerable<TempExtraPayment> Create(TempExtraPayment extraPayment);

        void Update(TempExtraPayment extraPayment);

        void Clear(TempExtraPayment extraPayment);
    }
}
