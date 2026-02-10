using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface ILiabilityRepository : IRepository<Liability>
    {
        IQueryable<LiabilityList>? GetList(PagingRequest request);

        void InsertOpeningLoan(int payeeId);

        IEnumerable<LiabilityTxList> GetTxPagedList(LiabilityTxListReq request);

        int TxCount(LiabilityTxListReq request);

        int ImportTax(ImportTaxReq importTaxReq);

        int SaveLoanPayment(LiabilityPaymentReq paymentReq);

        int SaveCCPayment(LiabilityPaymentReq paymentReq);
    }
}
