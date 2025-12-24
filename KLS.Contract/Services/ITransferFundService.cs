using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ITransferFundService
    {
        PagingResponse<TransferFundList> GetPagedTransferFunds(TFReq tFReq);

        TransferFund GetById(int tfId);

        TransferFundList? SaveTransferFund(TransferFund transferFund);

        void DeleteTransferFund(int tfId);


        PagingResponse<DepositList> GetPagedDeposits(DepositReq depositReq);

        DepositList? SaveDeposit(TransferFund transferFund);

        IEnumerable<TempDepositList>? InjectDeposit(int tfId);
    }
}
