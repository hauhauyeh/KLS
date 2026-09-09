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

            return BuildDepositExportWorkbook(summaryRows, detailRows);
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
            IEnumerable<DepositExportSummaryRow> summaryRows,
            IEnumerable<DepositExportDetailRow> detailRows)
        {
            using var workbook = new XLWorkbook();

            var summarySheet = workbook.Worksheets.Add("Deposit Summary");
            WriteDepositSummarySheet(summarySheet, summaryRows);

            var detailSheet = workbook.Worksheets.Add("Payment Details");
            WriteDepositDetailSheet(detailSheet, detailRows);

            using var stream = new MemoryStream();
            workbook.SaveAs(stream);

            return stream.ToArray();
        }

        private static void WriteDepositSummarySheet(IXLWorksheet sheet, IEnumerable<DepositExportSummaryRow> rows)
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

            WriteHeaders(sheet, headers);

            var rowNumber = 2;
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

            FormatDepositExportSheet(sheet);
        }

        private static void WriteDepositDetailSheet(IXLWorksheet sheet, IEnumerable<DepositExportDetailRow> rows)
        {
            var headers = new[]
            {
                "Deposit #",
                "Deposit Date",
                "To Account",
                "Payment #",
                "Payment Date",
                "Payment Method",
                "Payment Reference",
                "Customer",
                "Payment Amount",
                "Deposit Detail Amount",
                "Invoice #",
                "Invoice Date",
                "Invoice Total",
                "Payment Applied",
                "Discount Applied",
                "Payment Discount",
                "Short Discount",
                "Other Discount",
                "Detail Role",
                "Detail Notes"
            };

            WriteHeaders(sheet, headers);

            var rowNumber = 2;
            foreach (var row in rows)
            {
                sheet.Cell(rowNumber, 1).Value = row.TFNumber;
                SetDateCell(sheet, rowNumber, 2, row.TFDate);
                sheet.Cell(rowNumber, 3).Value = row.ToAccount ?? string.Empty;
                SetIntCell(sheet, rowNumber, 4, row.PaymentNumber);
                SetDateCell(sheet, rowNumber, 5, row.PaymentDate);
                sheet.Cell(rowNumber, 6).Value = row.PaymentMethod ?? string.Empty;
                sheet.Cell(rowNumber, 7).Value = row.PaymentReference ?? string.Empty;
                sheet.Cell(rowNumber, 8).Value = row.Customer ?? string.Empty;
                SetDecimalCell(sheet, rowNumber, 9, row.PaymentAmount);
                SetDecimalCell(sheet, rowNumber, 10, row.DepositDetailAmount);
                SetIntCell(sheet, rowNumber, 11, row.InvoiceNumber);
                SetDateTimeCell(sheet, rowNumber, 12, row.InvoiceDate);
                SetDecimalCell(sheet, rowNumber, 13, row.InvoiceTotal);
                SetDecimalCell(sheet, rowNumber, 14, row.PaymentApplied);
                SetDecimalCell(sheet, rowNumber, 15, row.DiscountApplied);
                SetDecimalCell(sheet, rowNumber, 16, row.PaymentDiscount);
                SetDecimalCell(sheet, rowNumber, 17, row.ShortDiscount);
                SetDecimalCell(sheet, rowNumber, 18, row.OtherDiscount);
                sheet.Cell(rowNumber, 19).Value = row.DetailRole ?? string.Empty;
                sheet.Cell(rowNumber, 20).Value = row.DetailNotes ?? string.Empty;
                rowNumber++;
            }

            FormatDepositExportSheet(sheet);
        }

        private static void WriteHeaders(IXLWorksheet sheet, IReadOnlyList<string> headers)
        {
            for (var i = 0; i < headers.Count; i++)
            {
                sheet.Cell(1, i + 1).Value = headers[i];
            }

            sheet.Row(1).Style.Font.Bold = true;
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

        private static void FormatDepositExportSheet(IXLWorksheet sheet)
        {
            sheet.Columns().AdjustToContents();
            sheet.SheetView.FreezeRows(1);
        }
    }
}
