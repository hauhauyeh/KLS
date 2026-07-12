using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class VendorPaymentService : BaseService, IVendorPaymentService
    {
        private readonly ISystemSettingService _systemSettingService;
        private readonly IDeleteLogService _deleteLogService;
        private IWebHostEnvironment _hostingEnvironment;

        public VendorPaymentService(IUnitOfWork uow, ISystemSettingService systemSettingService, IDeleteLogService deleteLogService, IWebHostEnvironment hostingEnvironment) : base(uow)
        {
            _systemSettingService = systemSettingService;
            _deleteLogService = deleteLogService;
            _hostingEnvironment = hostingEnvironment;
        }

        public PagingResponse<VendorPaymentList> GetPagedVendorPayments(VendorPaymentReq vendorPaymentReq)
        {
            var list = Uow.VendorPayments.GetPagedVendorPayments(vendorPaymentReq);

            var totalRecords = Uow.VendorPayments.CountVendorPayments(vendorPaymentReq);

            return new PagingResponse<VendorPaymentList>(totalRecords, vendorPaymentReq.Pageno, vendorPaymentReq.Pagesize)
            {
                RowData = list,
            };
        }

        public VendorPayment GetById(int vendorPaymentId)
        {
            if (vendorPaymentId > 0)
                return Uow.VendorPayments.GetById(vendorPaymentId);
            else
                return new VendorPayment
                {
                    PaymentDate = DateOnly.FromDateTime(DateTime.Now),
                    PaymentMethod = EnumHelper.EnumPaymentMethod.ACH.ToString(),
                    FromAccountId = _systemSettingService.GetByKey<int>(GlobalKey.PAYMENT_DEFAULT_BANK),
                    PaymentType = "Bill Payment"
                };
        }

        public VendorPaymentList? GetListById(int vendorPaymentId)
        {
            var payNowReq = new VendorPaymentReq
            {
                Id = vendorPaymentId
            };

            return Uow.VendorPayments.GetPagedVendorPayments(payNowReq).AsEnumerable().FirstOrDefault();
        }

        public VendorPayment? Save(VendorPayment vendorPayment)
        {
            var newPaymentId = Uow.VendorPayments.Save(vendorPayment);

            return GetById(newPaymentId);
        }

        public void Delete(int vendorPaymentId)
        {
            var payment = GetById(vendorPaymentId);

            if (payment != null && !payment.IsLocked)
            {
                // Refund issue flow stores the issued vendor payment id on the source AsRefund row.
                // If that vendor payment is deleted later, release the source row back into the
                // refund queue by clearing the execution linkage before removing the vendor payment.
                Uow.CustomerPaymentDetails
                    .Find(x => x.RefundPaymentId == vendorPaymentId)
                    .ExecuteUpdate(setters => setters
                        .SetProperty(x => x.RefundPaymentId, x => null)
                        .SetProperty(x => x.RefundedAt, x => null));

                Uow.VendorPayments.Find(c => c.VendorPaymentId == vendorPaymentId).ExecuteDelete();

                string docType = payment.PaymentType.ToString();

                _deleteLogService.Add(docType, vendorPaymentId);
            }
        }

        public void VoidCheck(int vendorPaymentId)
        {
            Uow.VendorPayments.VoidCheck(vendorPaymentId);
        }

        public void UnVoidCheck(int vendorPaymentId)
        {
            Uow.VendorPayments.UnVoidCheck(vendorPaymentId);
        }

        public void Return(VendorPaymentReturnReq checkReq)
        {
            Uow.VendorPayments.Return(checkReq);
        }

        public void DeleteReturn(int vendorPaymentId)
        {
            Uow.VendorPayments.DeleteReturn(vendorPaymentId);
        }

        public List<string> GetReturnTypes()
        {
            var types = new List<string>();

            foreach (var enumValue in Enum.GetValues<EnumHelper.ReturnTypes>())
            {
                var field = enumValue.GetType().GetField(enumValue.ToString());

                if (Attribute.GetCustomAttribute(field, typeof(DisplayAttribute)) is DisplayAttribute attribute)
                {
                    types.Add(attribute.Name);
                }
            }

            return types;
        }

        public VendorPaymentList? SavePayNow(PayNowReq payNowReq)
        {
            var newPaymentId = Uow.VendorPayments.SavePayNow(payNowReq);

            return GetListById(newPaymentId);
        }

        #region --- PayNow Import (preview then commit) ---

        /// <summary>Uploaded workbooks live here. Under wwwroot/Payroll because OPENROWSET opens the
        /// file as the SQL Server service account, which already reads that folder. The app-pool
        /// identity's temp folder is typically not readable by SQL Server.</summary>
        private const string ImportSubFolder = "_import";

        private static readonly TimeSpan ImportFileRetention = TimeSpan.FromHours(24);

        /// <summary>
        /// Step 1. Store the workbook under a token and return what the importer will read from it,
        /// grouped into the payments it will create, with every row validated against the database.
        /// Writes nothing to the accounting tables.
        /// </summary>
        public ImportPayNowPreviewRes ImportPayNowPreview(ImportPayNowPreviewReq req)
        {
            if (req.ExcelFile == null || req.ExcelFile.Length == 0)
                throw new Exception("Please upload an Excel file.");

            var extension = Path.GetExtension(req.ExcelFile.FileName);
            if (!string.Equals(extension, ".xlsx", StringComparison.OrdinalIgnoreCase))
                throw new Exception("Only .xlsx import is supported.");

            var importRoot = GetImportRoot();
            Directory.CreateDirectory(importRoot);
            SweepExpiredImportFiles(importRoot);

            var token = Guid.NewGuid().ToString("N");
            var filePath = GetImportFilePath(token);

            using (var stream = new FileStream(filePath, FileMode.Create, FileAccess.Write))
            {
                req.ExcelFile.CopyTo(stream);
            }

            ImportPayNowPreviewRes preview;
            try
            {
                preview = BuildPreview(filePath);
            }
            catch
            {
                // An unreadable workbook leaves nothing worth keeping.
                TryDeleteImportFile(filePath);
                throw;
            }

            preview.UploadToken = token;
            preview.FileName = req.ExcelFile.FileName;

            return preview;
        }

        /// <summary>
        /// Step 2. Commit the previewed workbook. Re-validates everything: the client's disabled
        /// Import button is UX, not a control.
        /// </summary>
        public int ImportPayNow(ImportPayNowCommitReq req)
        {
            if (string.IsNullOrWhiteSpace(req.PaymentMethod)
                || !Uow.PaymentOptions.Exists(p => p.MethodName == req.PaymentMethod))
                throw new Exception("Select a valid payment method.");

            if (req.FromAccountId <= 0
                || !Uow.Accounts.Exists(a => a.AccountId == req.FromAccountId))
                throw new Exception("Select a valid from-account.");

            var filePath = GetImportFilePath(req.UploadToken);
            if (!File.Exists(filePath))
                throw new Exception("The uploaded file expired. Please upload it again.");

            // The file on disk is the source of truth, not whatever the client last saw.
            var preview = BuildPreview(filePath);
            if (preview.HasErrors)
                throw new Exception("The uploaded file has validation errors and cannot be imported. Upload it again after fixing the highlighted rows.");

            var txCount = Uow.VendorPayments.ImportPayNow(new ImportPayNow
            {
                PaymentMethod = req.PaymentMethod,
                FromAccountId = req.FromAccountId,
                FilePath = filePath
            });

            // The payments are committed. Cleanup failure must never turn that into an error.
            TryDeleteImportFile(filePath);

            return txCount;
        }

        /// <summary>
        /// The single source of the import's validation rules, used by both the preview the user
        /// approves and the gate the commit enforces, so the two cannot drift apart.
        /// </summary>
        private ImportPayNowPreviewRes BuildPreview(string filePath)
        {
            var rows = Uow.VendorPayments.ImportPayNowPreview(filePath);

            if (rows.Count == 0)
                throw new Exception("No transaction rows were found in the Excel file.");

            var res = new ImportPayNowPreviewRes { TotalRows = rows.Count };

            // Null batches sort first: they are always errors and should lead the list.
            var groups = rows
                .GroupBy(r => r.Batch)
                .OrderBy(g => g.Key.HasValue)
                .ThenBy(g => g.Key);

            foreach (var group in groups)
            {
                // The importer reads its batch-level fields with SELECT TOP(1) and no ORDER BY,
                // which in practice yields the first inserted row. Mirror that with the lowest RowNo.
                var ordered = group.OrderBy(r => r.RowNo).ToList();
                var head = ordered[0];

                var batch = new ImportPayNowBatch
                {
                    Batch = group.Key,
                    PayeeId = head.PayeeId,
                    PayeeName = head.DbPayeeName,
                    PaymentDate = head.ArrivalDate,
                    PmtRefNum = head.PmtRefNum,
                    BankDate = head.BankDate,
                    IsLocked = head.BankDate.HasValue,
                    Amount = ordered.Sum(r => r.PmtAmount ?? 0m)
                };

                foreach (var row in ordered)
                    batch.Rows.Add(BuildRow(row));

                EvaluateBatch(batch, ordered, head);

                // The batch is as bad as its worst row.
                foreach (var row in batch.Rows)
                    batch.Status = ImportPayNowStatus.Worst(batch.Status, row.Status);

                res.Batches.Add(batch);
            }

            res.BatchCount = res.Batches.Count;
            res.TotalAmount = res.Batches.Sum(b => b.Amount);
            res.HasErrors = res.Batches.Any(b => b.Status == ImportPayNowStatus.Error);

            return res;
        }

        private static ImportPayNowRow BuildRow(ImportPayNowExcelRow src)
        {
            var row = new ImportPayNowRow
            {
                RowNo = src.RowNo,
                AccountCode = src.AccountCode,
                AccountName = src.DbAccountName,
                PmtAmount = src.PmtAmount,
                Note = src.Note
            };

            // --- Errors: the importer would fail, or post something wrong, on this row.

            if (!src.Batch.HasValue)
                AddError(row, "Batch is required.");

            if (!src.PayeeId.HasValue)
                AddError(row, "PayeeId is required.");
            else if (src.DbPayeeName == null)
                AddError(row, $"PayeeId {src.PayeeId} does not match any payee.");

            if (string.IsNullOrWhiteSpace(src.AccountCode))
                AddError(row, "AccountCode is required.");
            else if (src.AccountMatchCount == 0)
                AddError(row, $"Account code '{src.AccountCode}' does not match any account.");
            else if (src.AccountMatchCount > 1)
                AddError(row, $"Account code '{src.AccountCode}' matches {src.AccountMatchCount} accounts and is ambiguous.");

            if (!src.PmtAmount.HasValue)
                AddError(row, "Amount is required. Check that the PmtAmount column is formatted as a number.");

            if (!src.ArrivalDate.HasValue)
                AddError(row, "ArrivalDate is required. It becomes the payment date.");

            // --- Warnings: the importer will accept this, but it is probably not what was meant.

            if (src.PmtAmount == 0m)
                AddWarning(row, "Amount is zero.");

            if (src.DbPayeeName != null
                && !string.IsNullOrWhiteSpace(src.PayeeName)
                && !string.Equals(src.PayeeName.Trim(), src.DbPayeeName.Trim(), StringComparison.OrdinalIgnoreCase))
                AddWarning(row, $"Spreadsheet says '{src.PayeeName}' but PayeeId {src.PayeeId} is '{src.DbPayeeName}'. The payment posts to '{src.DbPayeeName}'.");

            if (src.DbAccountName != null
                && !string.IsNullOrWhiteSpace(src.AccountName)
                && !string.Equals(src.AccountName.Trim(), src.DbAccountName.Trim(), StringComparison.OrdinalIgnoreCase))
                AddWarning(row, $"Spreadsheet says '{src.AccountName}' but account code '{src.AccountCode}' is '{src.DbAccountName}'. The line posts to '{src.DbAccountName}'.");

            return row;
        }

        private static void EvaluateBatch(ImportPayNowBatch batch, List<ImportPayNowExcelRow> rows, ImportPayNowExcelRow head)
        {
            // The importer takes TOP(1) payee for the batch and posts every line in it to that one
            // vendor, silently. Name the payees so the mistake is obvious.
            if (head.BatchPayeeCount > 1)
            {
                var payees = rows
                    .Where(r => r.PayeeId.HasValue)
                    .Select(r => $"{r.PayeeId} ({r.DbPayeeName ?? "unknown"})")
                    .Distinct();

                AddError(batch, $"Batch contains more than one PayeeId: {string.Join(", ", payees)}. Every line would post to the first one.");
            }

            if (batch.Amount == 0m)
                AddWarning(batch, "Batch total is zero.");

            if (batch.IsLocked)
                AddWarning(batch, "BankDate is set, so this payment will be created locked and cannot be edited afterwards.");

            // The importer nulls the note when a batch has more than one row.
            if (rows.Count > 1 && rows.Any(r => !string.IsNullOrWhiteSpace(r.Note)))
                AddWarning(batch, "This payment has multiple lines, so its note will not be saved on the payment.");

            if (head.IsDuplicate)
                AddWarning(batch, "A payment with the same vendor, reference and amount already exists. This may be a re-import.");
        }

        private static void AddError(ImportPayNowRow row, string message)
        {
            row.Messages.Add(message);
            row.Status = ImportPayNowStatus.Error;
        }

        private static void AddWarning(ImportPayNowRow row, string message)
        {
            row.Messages.Add(message);
            row.Status = ImportPayNowStatus.Worst(row.Status, ImportPayNowStatus.Warning);
        }

        private static void AddError(ImportPayNowBatch batch, string message)
        {
            batch.Messages.Add(message);
            batch.Status = ImportPayNowStatus.Error;
        }

        private static void AddWarning(ImportPayNowBatch batch, string message)
        {
            batch.Messages.Add(message);
            batch.Status = ImportPayNowStatus.Worst(batch.Status, ImportPayNowStatus.Warning);
        }

        private string GetImportRoot()
        {
            return Path.Combine(_hostingEnvironment.WebRootPath, Constants.PayrollPath, ImportSubFolder);
        }

        /// <summary>
        /// The token is concatenated into a file path and into an OPENROWSET connection string,
        /// so anything that is not a GUID is rejected outright.
        /// </summary>
        private string GetImportFilePath(string? token)
        {
            if (string.IsNullOrWhiteSpace(token) || !Guid.TryParseExact(token, "N", out _))
                throw new Exception("The uploaded file expired. Please upload it again.");

            return Path.Combine(GetImportRoot(), $"{token}.xlsx");
        }

        /// <summary>ACE keeps a handle on the workbook, so a delete can legitimately fail. Never let that surface.</summary>
        private static void TryDeleteImportFile(string filePath)
        {
            try
            {
                GC.Collect();

                if (File.Exists(filePath))
                    File.Delete(filePath);
            }
            catch
            {
                // Left behind for the sweep. Not worth failing a committed import over.
            }
        }

        /// <summary>Reclaims abandoned previews. Cheap enough to run on every upload; no scheduler needed.</summary>
        private static void SweepExpiredImportFiles(string importRoot)
        {
            try
            {
                var cutoff = DateTime.UtcNow - ImportFileRetention;

                foreach (var file in Directory.EnumerateFiles(importRoot, "*.xlsx"))
                {
                    if (File.GetLastWriteTimeUtc(file) < cutoff)
                        TryDeleteImportFile(file);
                }
            }
            catch
            {
                // Housekeeping must never block an upload.
            }
        }

        #endregion


        public void SaveAdvance(VendorPaymentAdvanceReq req)
        {
            Uow.VendorPayments.SaveAdvance(req);
        }

        public IEnumerable<VendorPaymentList>? GetAdvances(int purchaseId)
        {
            return Uow.VendorPayments.GetByPurchaseId(purchaseId);
        }

        public VendorPaymentList? ApplyAdvance(AdvanceApplyReq req)
        {
            Uow.VendorPayments.ApplyAdvanceManual(req);
            return GetListById(req.VendorPaymentId);
        }

        public VendorPaymentList? UnapplyAdvance(int vendorPaymentId)
        {
            Uow.VendorPayments.UnapplyAdvance(vendorPaymentId);
            return GetListById(vendorPaymentId);
        }

        public IEnumerable<VendorAppliedBill>? GetAppliedBills(int vendorPaymentId)
        {
            return Uow.VendorPayments.GetAppliedBills(vendorPaymentId);
        }

        public IEnumerable<VendorPaymentOpenAdvance>? GetOpenAdvances(int payeeId)
        {
            return Uow.VendorPayments.GetOpenAdvances(payeeId);
        }


        public PagingResponse<CheckRegister> GetPagedCheckRegister(CheckRegisterReq checkRegisterReq)
        {
            var list = Uow.VendorPayments.GetPagedCheckRegister(checkRegisterReq);

            var totalRecords = Uow.VendorPayments.CountCheckRegister(checkRegisterReq);

            return new PagingResponse<CheckRegister>(totalRecords, checkRegisterReq.Pageno, checkRegisterReq.Pagesize)
            {
                RowData = list,
            };
        }

        public void UpdateBankDate(CheckRegister checkRegister)
        {
            Uow.VendorPayments.UpdateBankDate(checkRegister);
        }
    }
}
