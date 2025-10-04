using KLS.Models;
using KLS.Models.Deposit;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface ITransferFundRepository : IRepository<TransferFund>
    {
        IQueryable<TransferFundList> GetAllTransferFunds(TFReq tFReq);

        int CountAllTransferFunds(TFReq tFReq);

        int SaveTransferFund(TransferFund transferFund);


        IEnumerable<DepositList> GetAllDeposits(DepositReq depositReq);

        int CountAllDeposits(DepositReq depositReq);
    }
}
