using KLS.Models;
using KLS.Models.Deposit;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface ITransferFundService
    {
        PagingResponse<TransferFundList> GetAllTransferFunds(TFReq tFReq);

        TransferFund GetById(int tfId);

        TransferFundList? SaveTransferFund(TransferFund transferFund);

        void DeleteTransferFund(int tfId);


        PagingResponse<DepositList> GetAllDeposits(DepositReq depositReq);
    }
}
