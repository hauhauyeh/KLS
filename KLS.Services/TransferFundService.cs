using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.EntityFrameworkCore;
using Org.BouncyCastle.Ocsp;
using System;
using System.Collections.Generic;
using System.Globalization;
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

        public byte[] ExportDeposits(DepositReq depositReq)
        {
            var countReq = CloneDepositReq(depositReq);
            var totalRecords = Uow.TransferFunds.CountDeposits(countReq);

            var rows = Enumerable.Empty<DepositList>();
            if (totalRecords > 0)
            {
                var exportReq = CloneDepositReq(depositReq);
                exportReq.Pageno = 1;
                exportReq.Pagesize = totalRecords;
                exportReq.IsCount = false;

                rows = Uow.TransferFunds.GetPagedDeposits(exportReq).AsEnumerable();
            }

            return Encoding.UTF8.GetBytes(BuildDepositCsv(rows));
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

        private static DepositReq CloneDepositReq(DepositReq req)
        {
            return new DepositReq
            {
                Pageno = req.Pageno,
                Pagesize = req.Pagesize,
                Search = req.Search,
                IsCount = req.IsCount,
                StartDate = req.StartDate,
                EndDate = req.EndDate,
                Id = req.Id,
                Filterby = req.Filterby,
                SortField = req.SortField,
                SortOrder = req.SortOrder,
                ToAccountId = req.ToAccountId,
                Uncleared = req.Uncleared
            };
        }

        private static string BuildDepositCsv(IEnumerable<DepositList> rows)
        {
            var csv = new StringBuilder();
            csv.AppendLine("Deposit#,Date,To Account,Amount,Cash Back Account,Cash Back Amount,CC Fee,Locked");

            foreach (var row in rows)
            {
                csv.AppendLine(string.Join(",", new[]
                {
                    CsvCell(row.TFNumber),
                    CsvCell(row.TFDate?.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)),
                    CsvCell(row.ToAccount),
                    CsvCell(FormatMoney(row.TransferAmount)),
                    CsvCell(row.CashBackAccount),
                    CsvCell(FormatMoney(row.CashBackAmount)),
                    CsvCell(FormatMoney(row.CCFeeAmount)),
                    CsvCell(row.IsLocked ? "Yes" : "No")
                }));
            }

            return csv.ToString();
        }

        private static string FormatMoney(decimal? value)
        {
            return value.HasValue ? value.Value.ToString("0.00", CultureInfo.InvariantCulture) : string.Empty;
        }

        private static string CsvCell(object? value)
        {
            var text = Convert.ToString(value, CultureInfo.InvariantCulture) ?? string.Empty;
            if (!text.Contains(',') && !text.Contains('"') && !text.Contains('\r') && !text.Contains('\n'))
                return text;

            return $"\"{text.Replace("\"", "\"\"")}\"";
        }
    }
}
