using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface ITransferFundRepository : IRepository<TransferFund>
    {
        IQueryable<TransferFundList> GetPagedTransferFunds(TFReq tFReq);

        int CountTransferFunds(TFReq tFReq);

        int SaveTransferFund(TransferFund transferFund);


        IQueryable<DepositList> GetPagedDeposits(DepositReq depositReq);

        IQueryable<DepositExportDetailRow> ExportDepositDetails(DepositReq depositReq);

        int CountDeposits(DepositReq depositReq);

        int SaveDeposit(TransferFund transferFund);

        IQueryable<TempDepositList>? InjectDeposit(DepositInjectReq injectReq);
    }
}
