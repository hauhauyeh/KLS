using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.EntityFrameworkCore;
using Org.BouncyCastle.Ocsp;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class TransferFundService : BaseService, ITransferFundService
    {
        private readonly IDeleteLogService _deleteLogService;

        public TransferFundService(IUnitOfWork uow, IDeleteLogService deleteLogService) : base(uow)
        {
            _deleteLogService = deleteLogService;
        }

        public PagingResponse<TransferFundList> GetPagedTransferFunds(TFReq tFReq)
        {
            var transferfundlist = Uow.TransferFunds.GetPagedTransferFunds(tFReq);

            var totalRecords = Uow.TransferFunds.CountTransferFunds(tFReq);

            //tFReq.IsCount = true;

            return new PagingResponse<TransferFundList>(totalRecords, tFReq.Pageno, tFReq.Pagesize)
            {
                RowData = transferfundlist,
            };
        }

        public TransferFund GetById(int tfId)
        {
            return Uow.TransferFunds.GetById(tfId);
        }

        public TransferFundList? GetListById(int tfId)
        {
            var tfReq = new TFReq
            {
                Id = tfId
            };

            return Uow.TransferFunds.GetPagedTransferFunds(tfReq).AsEnumerable().FirstOrDefault();
        }

        public TransferFundList? SaveTransferFund(TransferFund transferFund)
        {
            var newTFId = Uow.TransferFunds.SaveTransferFund(transferFund);

            return GetListById(newTFId);
        }

        public void DeleteTransferFund(int tfId)
        {
            var tf = GetById(tfId);

            if (tf != null && !tf.IsLocked)
            {
                Uow.TransferFunds.Find(c => c.TFId == tfId).ExecuteDelete();
                //there is instead of delete trigger that's why we use ExecuteDelete.

                string docType = tf.TFType == "DEPOSIT" ? EnumHelper.DocType.Deposit.ToString() : EnumHelper.DocType.Transfer.ToString();

                _deleteLogService.Add(docType, tfId);
            }
        }


        public PagingResponse<DepositList> GetPagedDeposits(DepositReq depositReq)
        {
            var list = Uow.TransferFunds.GetPagedDeposits(depositReq);

            var totalRecords = Uow.TransferFunds.CountDeposits(depositReq);

            return new PagingResponse<DepositList>(totalRecords, depositReq.Pageno, depositReq.Pagesize)
            {
                RowData = list,
            };
        }

        public DepositList? GetDepositListById(int tfId)
        {
            var depositReq = new DepositReq
            {
                Id = tfId
            };

            return Uow.TransferFunds.GetPagedDeposits(depositReq).AsEnumerable().FirstOrDefault();
        }

        public DepositList? SaveDeposit(TransferFund transferFund)
        {
            var newTFId = Uow.TransferFunds.SaveDeposit(transferFund);

            return GetDepositListById(newTFId);
        }

        public IEnumerable<TempDepositList>? InjectDeposit(DepositInjectReq injectReq)
        {
            return Uow.TransferFunds.InjectDeposit(injectReq);
        }
    }
}
