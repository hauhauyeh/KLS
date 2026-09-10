using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using ClosedXML.Excel;
using Microsoft.EntityFrameworkCore;
using Org.BouncyCastle.Ocsp;
using System;
using System.IO;
using System.Collections.Generic;
using System.Linq;
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
            var detailRows = Uow.TransferFunds.ExportDepositDetails(depositReq).AsEnumerable().ToList();
            var summaryRows = BuildDepositExportSummaryRows(detailRows);
            var toAccountName = ResolveDepositExportToAccountName(depositReq, detailRows);

            return BuildDepositExportWorkbook(depositReq, toAccountName, summaryRows, detailRows);
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

        private static List<DepositExportSummaryRow> BuildDepositExportSummaryRows(IEnumerable<DepositExportDetailRow> detailRows)
        {
            return detailRows
                .GroupBy(x => new
                {
                    x.TFId,
                    x.TFNumber,
                    x.TFDate,
                    x.ToAccount,
                    x.TransferAmount,
                    x.CashBackAccount,
                    x.CashBackAmount,
                    x.CCFeeAmount,
                    x.IsLocked
                })
                .Select(g => new DepositExportSummaryRow
                {
                    TFId = g.Key.TFId,
                    TFNumber = g.Key.TFNumber,
                    TFDate = g.Key.TFDate,
                    ToAccount = g.Key.ToAccount,
                    TransferAmount = g.Key.TransferAmount,
                    CashBackAccount = g.Key.CashBackAccount,
                    CashBackAmount = g.Key.CashBackAmount,
                    CCFeeAmount = g.Key.CCFeeAmount,
                    IsLocked = g.Key.IsLocked,
                    PaymentCount = g
                        .Where(x => x.CustomerPaymentId.HasValue)
                        .Select(x => x.CustomerPaymentId!.Value)
                        .Distinct()
                        .Count(),
                    DetailLineCount = g.Count(x => x.PaymentDetailId.HasValue)
                })
                .ToList();
        }

        private static byte[] BuildDepositExportWorkbook(
            DepositReq depositReq,
            string toAccountName,
            IEnumerable<DepositExportSummaryRow> summaryRows,
            IEnumerable<DepositExportDetailRow> detailRows)
        {
            using var workbook = new XLWorkbook();

            var summarySheet = workbook.Worksheets.Add("Deposit Summary");
            WriteDepositSummarySheet(summarySheet, depositReq, toAccountName, summaryRows);

            var detailSheet = workbook.Worksheets.Add("Payment Details");
            WriteDepositDetailSheet(detailSheet, depositReq, toAccountName, detailRows);

            using var stream = new MemoryStream();
            workbook.SaveAs(stream);

            return stream.ToArray();
        }

        private string ResolveDepositExportToAccountName(DepositReq depositReq, IEnumerable<DepositExportDetailRow> rows)
        {
            if (!depositReq.ToAccountId.HasValue)
                return "All";

            var rowAccountName = rows
                .Select(x => x.ToAccount)
                .FirstOrDefault(x => !string.IsNullOrWhiteSpace(x));

            if (!string.IsNullOrWhiteSpace(rowAccountName))
                return rowAccountName;

            return Uow.Accounts
                .Find(x => x.AccountId == depositReq.ToAccountId.Value)
                .Select(x => x.AccountName)
                .FirstOrDefault() ?? "Selected Account";
        }

        private static void WriteDepositSummarySheet(IXLWorksheet sheet, DepositReq depositReq, string toAccountName, IEnumerable<DepositExportSummaryRow> rows)
        {
            var headers = new[]
            {
                "Deposit #",
                "Deposit Date",
                "To Account",
                "Deposit Amount",
                "Cash Back Account",
                "Cash Back Amount",
                "CC Fee",
                "Locked",
                "Payment Count",
                "Detail Line Count"
            };

            WriteReportHeader(sheet, depositReq, toAccountName);
            WriteHeaders(sheet, headers, 5);

            var rowNumber = 6;
            foreach (var row in rows)
            {
                sheet.Cell(rowNumber, 1).Value = row.TFNumber;
                SetDateCell(sheet, rowNumber, 2, row.TFDate);
                sheet.Cell(rowNumber, 3).Value = row.ToAccount ?? string.Empty;
                SetDecimalCell(sheet, rowNumber, 4, row.TransferAmount);
                sheet.Cell(rowNumber, 5).Value = row.CashBackAccount ?? string.Empty;
                SetDecimalCell(sheet, rowNumber, 6, row.CashBackAmount);
                SetDecimalCell(sheet, rowNumber, 7, row.CCFeeAmount);
                sheet.Cell(rowNumber, 8).Value = row.IsLocked ? "Yes" : "No";
                sheet.Cell(rowNumber, 9).Value = row.PaymentCount;
                sheet.Cell(rowNumber, 10).Value = row.DetailLineCount;
                rowNumber++;
            }

            FormatDepositExportSheet(sheet, 5);
        }

        private static void WriteDepositDetailSheet(IXLWorksheet sheet, DepositReq depositReq, string toAccountName, IEnumerable<DepositExportDetailRow> rows)
        {
            var headers = new[]
            {
                "Payment Date",
                "Payment Method",
                "Payment Reference",
                "Customer",
                "Payment Amount",
                "Sales Doc #",
                "Invoice Date",
                "Invoice Total",
                "Payment Applied"
            };

            WriteReportHeader(sheet, depositReq, toAccountName);
            WriteHeaders(sheet, headers, 5);

            var rowNumber = 6;
            foreach (var row in rows)
            {
                SetDateCell(sheet, rowNumber, 1, row.PaymentDate);
                sheet.Cell(rowNumber, 2).Value = row.PaymentMethod ?? string.Empty;
                sheet.Cell(rowNumber, 3).Value = row.PaymentReference ?? string.Empty;
                sheet.Cell(rowNumber, 4).Value = row.Customer ?? string.Empty;
                SetDecimalCell(sheet, rowNumber, 5, row.PaymentAmount);
                sheet.Cell(rowNumber, 6).Value = GetSalesDocDisplay(row);
                SetDateTimeCell(sheet, rowNumber, 7, row.InvoiceDate);
                SetDecimalCell(sheet, rowNumber, 8, row.InvoiceTotal);

                if (ShouldShowPaymentApplied(row.PaymentApplied, row.InvoiceTotal))
                    SetDecimalCell(sheet, rowNumber, 9, row.PaymentApplied);

                rowNumber++;
            }

            FormatDepositExportSheet(sheet, 5);
        }

        private static void WriteReportHeader(IXLWorksheet sheet, DepositReq depositReq, string toAccountName)
        {
            sheet.Cell(1, 1).Value = "Deposit Export";
            sheet.Cell(1, 1).Style.Font.Bold = true;
            sheet.Cell(2, 1).Value = FormatDepositExportDateRange(depositReq);
            sheet.Cell(3, 1).Value = $"To Account: {toAccountName}";
        }

        private static string FormatDepositExportDateRange(DepositReq depositReq)
        {
            if (depositReq.StartDate.HasValue && depositReq.EndDate.HasValue)
                return $"Date Range: {depositReq.StartDate.Value:yyyy-MM-dd} to {depositReq.EndDate.Value:yyyy-MM-dd}";

            if (depositReq.StartDate.HasValue)
                return $"Date Range: From {depositReq.StartDate.Value:yyyy-MM-dd}";

            if (depositReq.EndDate.HasValue)
                return $"Date Range: Through {depositReq.EndDate.Value:yyyy-MM-dd}";

            return "Date Range: All";
        }

        private static string GetSalesDocDisplay(DepositExportDetailRow row)
        {
            if (!string.IsNullOrWhiteSpace(row.SalesDocNum))
                return row.SalesDocNum;

            return row.InvoiceNumber?.ToString() ?? string.Empty;
        }

        private static bool ShouldShowPaymentApplied(decimal? paymentApplied, decimal? invoiceTotal)
        {
            if (!paymentApplied.HasValue)
                return false;

            if (!invoiceTotal.HasValue)
                return true;

            return Math.Round(paymentApplied.Value, 2) != Math.Round(invoiceTotal.Value, 2);
        }

        private static void WriteHeaders(IXLWorksheet sheet, IReadOnlyList<string> headers, int rowNumber)
        {
            for (var i = 0; i < headers.Count; i++)
            {
                sheet.Cell(rowNumber, i + 1).Value = headers[i];
            }

            sheet.Row(rowNumber).Style.Font.Bold = true;
        }

        private static void SetDateCell(IXLWorksheet sheet, int row, int column, DateOnly? value)
        {
            if (!value.HasValue)
                return;

            sheet.Cell(row, column).Value = value.Value.ToDateTime(TimeOnly.MinValue);
            sheet.Cell(row, column).Style.DateFormat.Format = "yyyy-mm-dd";
        }

        private static void SetDateTimeCell(IXLWorksheet sheet, int row, int column, DateTime? value)
        {
            if (!value.HasValue)
                return;

            sheet.Cell(row, column).Value = value.Value;
            sheet.Cell(row, column).Style.DateFormat.Format = "yyyy-mm-dd";
        }

        private static void SetDecimalCell(IXLWorksheet sheet, int row, int column, decimal? value)
        {
            if (!value.HasValue)
                return;

            sheet.Cell(row, column).Value = value.Value;
        }

        private static void SetIntCell(IXLWorksheet sheet, int row, int column, int? value)
        {
            if (!value.HasValue)
                return;

            sheet.Cell(row, column).Value = value.Value;
        }

        private static void FormatDepositExportSheet(IXLWorksheet sheet, int freezeRow)
        {
            sheet.Columns().AdjustToContents();
            sheet.SheetView.FreezeRows(freezeRow);
        }
    }
}
