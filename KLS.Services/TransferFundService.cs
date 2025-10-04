using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Models.Deposit;
using KLS.Services.Interfaces;
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
        public TransferFundService(IUnitOfWork uow) : base(uow)
        {
        }

        public PagingResponse<TransferFundList> GetAllTransferFunds(TFReq tFReq)
        {
            var transferfundlist = Uow.TransferFunds.GetAllTransferFunds(tFReq);

            var totalRecords = Uow.TransferFunds.CountAllTransferFunds(tFReq);

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

            return Uow.TransferFunds.GetAllTransferFunds(tfReq).ToList().FirstOrDefault();
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
            }
        }


        public PagingResponse<DepositList> GetAllDeposits(DepositReq depositReq)
        {
            var list = Uow.TransferFunds.GetAllDeposits(depositReq);

            var totalRecords = Uow.TransferFunds.CountAllDeposits(depositReq);

            return new PagingResponse<DepositList>(totalRecords, depositReq.Pageno, depositReq.Pagesize)
            {
                RowData = list,
            };
        }
    }
}
