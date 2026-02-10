using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ILiabilityService
    {
        IEnumerable<LiabilityList>? GetList(PagingRequest request);

        LiabilityDto GetById(int payeeId);

        bool NameExists(LiabilityDto dto);

        LiabilityDto Create(LiabilityDto dto);

        LiabilityDto? Update(LiabilityDto dto);

        void Delete(int payeeId);

        PagingResponse<LiabilityTxList> GetTxPagedList(LiabilityTxListReq request);

        int ImportTax(ImportTaxReq importTaxReq);

        VendorPayment SaveLoanPayment(LiabilityPaymentReq paymentReq);

        VendorPayment SaveCCPayment(LiabilityPaymentReq paymentReq);
    }
}
