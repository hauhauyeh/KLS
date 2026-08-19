using System.Globalization;
using System.Text.RegularExpressions;
using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.VisualBasic.FileIO;

namespace KLS.Services
{
    public class BankFeedTransactionService : BaseService, IBankFeedTransactionService
    {
        private static readonly string TempRoot = Path.Combine(Path.GetTempPath(), "KLS", "BankFeed");

        public BankFeedTransactionService(IUnitOfWork uow) : base(uow)
        {
        }

        public BankFeedUploadPreviewRes UploadPreview(BankFeedUploadPreviewReq req)
        {
            if (req.File == null || req.File.Length == 0)
                throw new Exception("Please upload a CSV file.");

            var extension = Path.GetExtension(req.File.FileName);
            if (!string.Equals(extension, ".csv", StringComparison.OrdinalIgnoreCase))
                throw new Exception("Only CSV import is supported right now.");

            Directory.CreateDirectory(TempRoot);

            var token = Guid.NewGuid().ToString("N");
            var tempPath = GetTempFilePath(token);

            using (var stream = new FileStream(tempPath, FileMode.Create, FileAccess.Write))
            {
                req.File.CopyTo(stream);
            }

            var rows = ReadRawRows(tempPath);
            var maxColumns = rows.Any() ? rows.Max(c => c.Count) : 0;

            var response = new BankFeedUploadPreviewRes
            {
                UploadToken = token,
                FileName = req.File.FileName,
                TotalRows = rows.Count,
                Columns = Enumerable.Range(0, maxColumns)
                    .Select(i => new BankFeedPreviewColumn
                    {
                        Index = i,
                        Name = $"Column {i + 1}"
                    })
                    .ToList(),
                Rows = rows
                    .Select((values, idx) => new BankFeedPreviewRow
                    {
                        RowNo = idx + 1,
                        Values = values
                    })
                    .ToList()
            };

            if (rows.Count > 0)
                response.SuggestedMap = GuessMap(rows[0]);

            return response;
        }

        public int Import(BankFeedImportReq req)
        {
            if (req.AccountId <= 0)
                throw new Exception("Please select an account.");

            if (string.IsNullOrWhiteSpace(req.UploadToken))
                throw new Exception("Upload token is missing.");

            var path = GetTempFilePath(req.UploadToken);
            if (!File.Exists(path))
                throw new Exception("The uploaded CSV preview expired. Please upload the file again.");

            ValidateMap(req.Map);

            var bankFeedAccount = EnsureBankFeedAccount(req.AccountId);
            var rawRows = ReadRawRows(path);
            var dataRows = req.Map.HasHeaderRow ? rawRows.Skip(1).ToList() : rawRows;
            var batchId = Guid.NewGuid();
            var rowNo = 1;
            var items = new List<BankFeedTransaction>();

            foreach (var row in dataRows)
            {
                if (row.All(string.IsNullOrWhiteSpace))
                    continue;

                var postedDate = ParseDate(GetValue(row, req.Map.DateColumnIndex), req.Map.DateFormat);
                var description = GetValue(row, req.Map.DescriptionColumnIndex);
                if (string.IsNullOrWhiteSpace(description))
                    throw new Exception($"Description is required on row {rowNo}.");

                items.Add(new BankFeedTransaction
                {
                    BankFeedAccountId = bankFeedAccount.BankFeedAccountId,
                    ImportBatchId = batchId,
                    RowNo = rowNo,
                    PostedDate = postedDate,
                    Amount = ParseAmount(row, req.Map),
                    Description = description.Trim(),
                    ReferenceNo = req.Map.ReferenceColumnIndex.HasValue ? NullIfWhiteSpace(GetValue(row, req.Map.ReferenceColumnIndex.Value)) : null,
                    CheckNumber = req.Map.CheckNumberColumnIndex.HasValue ? NullIfWhiteSpace(GetValue(row, req.Map.CheckNumberColumnIndex.Value)) : null
                });

                rowNo++;
            }

            if (!items.Any())
                throw new Exception("No transaction rows were found in the CSV file.");

            Uow.BankFeedTransactions.AddRange(items);
            Uow.Commit();
            TryDeleteTempFile(path);

            return items.Count;
        }

        public PagingResponse<BankFeedTransactionList> GetList(BankFeedListReq req)
        {
            var list = Uow.BankFeedTransactions.GetPagedList(req);
            var count = Uow.BankFeedTransactions.CountList(req);

            return new PagingResponse<BankFeedTransactionList>(count, req.Pageno, req.Pagesize)
            {
                RowData = list
            };
        }

        public List<BankFeedMatchCandidate> GetMatchCandidates(long bankFeedTransactionId)
        {
            return Uow.BankFeedTransactions.GetMatchCandidates(bankFeedTransactionId).ToList();
        }

        public PagingResponse<BankFeedOpenBill> GetOpenBills(BankFeedOpenBillsReq req)
        {
            var list = Uow.BankFeedTransactions.GetOpenBills(req).ToList();
            var count = Uow.BankFeedTransactions.CountOpenBills(req);

            return new PagingResponse<BankFeedOpenBill>(count, req.Pageno, req.Pagesize)
            {
                RowData = list
            };
        }

        public PagingResponse<BankFeedUndepositedPayment> GetUndepositedPayments(BankFeedUndepositedPaymentsReq req)
        {
            var list = Uow.BankFeedTransactions.GetUndepositedPayments(req).ToList();
            var count = Uow.BankFeedTransactions.CountUndepositedPayments(req);

            return new PagingResponse<BankFeedUndepositedPayment>(count, req.Pageno, req.Pagesize)
            {
                RowData = list
            };
        }

        /// <summary>
        /// Everything here is a courtesy: the stored procedure re-checks all of it and is the
        /// authority. These run first only so the common mistakes give a readable message
        /// instead of a raw THROW.
        /// </summary>
        public int CreateVendorPayment(BankFeedCreateVendorPaymentReq req)
        {
            // 2026-08-12 resolve-only: a row may be entirely resolving lines (no bills).
            if ((req.Lines == null || !req.Lines.Any())
                && (req.ResolvingLines == null || !req.ResolvingLines.Any()))
                throw new Exception("Select at least one bill or enter a resolving line.");

            req.Lines ??= new List<BankFeedOpenBillLineReq>();

            if (req.Lines.Any(l => l.ApplyAmount <= 0))
                throw new Exception("Each selected bill needs an apply amount greater than zero.");

            if (req.Lines.Select(l => l.PurchaseId).Distinct().Count() != req.Lines.Count)
                throw new Exception("The same bill was selected more than once.");

            if (string.Equals(req.PaymentMethod, "CHECK", StringComparison.OrdinalIgnoreCase))
                throw new Exception("Check payments cannot be created from a bank feed row. Use ACH, E-Check, Cash, Handwrite Check or Credit Card.");

            var resolving = req.ResolvingLines ?? new List<BankFeedResolvingLineReq>();

            if (resolving.Any(l => l.Amount <= 0))
                throw new Exception("Each resolving line needs an amount greater than zero.");

            if (resolving.Any(l => l.PayeeId <= 0))
                throw new Exception("Each resolving line needs a vendor.");

            if (resolving.Count > 5)
                throw new Exception("A bank feed row can carry at most 5 resolving lines.");

            // Null rather than "[]" when no bills were selected (resolve-only row), mirroring
            // the resolving-lines contract below.
            var linesJson = req.Lines.Any()
                ? Newtonsoft.Json.JsonConvert.SerializeObject(
                    req.Lines.Select(l => new { l.PurchaseId, l.ApplyAmount, l.DiscountAmount }))
                : null;

            // Null rather than "[]" when there is nothing to resolve, so the procedure takes its
            // untouched pre-4B path rather than parsing an empty array.
            var resolvingJson = resolving.Any()
                ? Newtonsoft.Json.JsonConvert.SerializeObject(
                    resolving.Select(l => new { l.PayeeId, l.AccountId, l.Amount, l.Notes }))
                : null;

            return Uow.BankFeedTransactions.CreateVendorPayment(req, linesJson, resolvingJson, UserContext.EmpId);
        }

        /// <summary>
        /// Courtesy checks only, like CreateVendorPayment: BankFeed_CreateLiabilityPayment
        /// re-checks everything (kind, split rules, amounts) and is the authority.
        /// </summary>
        public int CreateLiabilityPayment(BankFeedCreateLiabilityPaymentReq req)
        {
            if (req.PayeeId <= 0)
                throw new Exception("Please select a liability payee.");

            if (string.Equals(req.PaymentMethod, "CHECK", StringComparison.OrdinalIgnoreCase))
                throw new Exception("Check payments cannot be created from a bank feed row. Use ACH, E-Check, Cash, Handwrite Check or Credit Card.");

            if (req.Principal < 0 || req.Interest < 0 || req.LateFee < 0)
                throw new Exception("Split amounts cannot be negative.");

            return Uow.BankFeedTransactions.CreateLiabilityPayment(req, UserContext.EmpId);
        }

        /// <summary>
        /// Tax + Loan manager payees for the liability-payment tab, tagged with the kind
        /// (LiabilityList has no PayeeType). Same rows Liability_GetList serves the managers.
        /// </summary>
        public List<BankFeedLiabilityPayeeDto> GetLiabilityPayees()
        {
            var taxes = Uow.Liabilities.GetList(new PagingRequest { Filterby = "Tax" })?.ToList()
                        ?? new List<LiabilityList>();
            var loans = Uow.Liabilities.GetList(new PagingRequest { Filterby = "Loan" })?.ToList()
                        ?? new List<LiabilityList>();

            return taxes.Select(x => new BankFeedLiabilityPayeeDto(x.PayeeId, x.PayeeName, x.BalanceRemaining, "Tax"))
                .Concat(loans.Select(x => new BankFeedLiabilityPayeeDto(x.PayeeId, x.PayeeName, x.BalanceRemaining, "Loan")))
                .ToList();
        }

        public PagingResponse<BankFeedOpenInvoice> GetOpenInvoices(BankFeedOpenInvoicesReq req)
        {
            if (req.PayeeId <= 0)
                throw new Exception("Please select a customer.");

            var list = Uow.BankFeedTransactions.GetOpenInvoices(req).ToList();
            var count = Uow.BankFeedTransactions.CountOpenInvoices(req);

            return new PagingResponse<BankFeedOpenInvoice>(count, req.Pageno, req.Pagesize)
            {
                RowData = list
            };
        }

        /// <summary>
        /// Courtesy checks only, like CreateVendorPayment: BankFeed_CreateDeposit re-checks
        /// everything and is the authority.
        /// </summary>
        public int CreateDeposit(BankFeedCreateDepositReq req)
        {
            if (req.CustomerPaymentIds == null || !req.CustomerPaymentIds.Any())
                throw new Exception("Please select at least one payment to deposit.");

            if (req.CustomerPaymentIds.Distinct().Count() != req.CustomerPaymentIds.Count)
                throw new Exception("The same payment was selected more than once.");

            var kinds = new[] { "None", "BankFee", "Rounding", "Account" };
            if (!kinds.Contains(req.DifferenceKind))
                throw new Exception("Unsupported difference kind.");

            if (req.DifferenceKind == "Account" && !req.DifferenceAccountId.HasValue)
                throw new Exception("Please choose the account for the difference.");

            if (req.DifferenceKind != "None" && string.IsNullOrWhiteSpace(req.DifferenceMemo))
                throw new Exception("A memo is required when a difference is allocated.");

            var paymentIdsJson = Newtonsoft.Json.JsonConvert.SerializeObject(req.CustomerPaymentIds);

            return Uow.BankFeedTransactions.CreateDeposit(req, paymentIdsJson, UserContext.EmpId);
        }

        /// <summary>
        /// Courtesy checks only: BankFeed_CreateCustomerPaymentDeposit re-checks everything
        /// and is the authority.
        /// </summary>
        public int CreateInvoiceDeposit(BankFeedCreateInvoiceDepositReq req)
        {
            if (req.PayeeId <= 0)
                throw new Exception("Please select a customer.");

            if (req.Lines == null || !req.Lines.Any())
                throw new Exception("Please select at least one invoice.");

            if (req.Lines.Select(l => l.SalesId).Distinct().Count() != req.Lines.Count)
                throw new Exception("The same invoice was selected more than once.");

            var kinds = new[] { "None", "BankFee", "Rounding", "Account" };
            if (!kinds.Contains(req.DifferenceKind))
                throw new Exception("Unsupported difference kind.");

            if (req.DifferenceKind == "Account" && !req.DifferenceAccountId.HasValue)
                throw new Exception("Please choose the account for the difference.");

            if (req.DifferenceKind != "None" && string.IsNullOrWhiteSpace(req.DifferenceMemo))
                throw new Exception("A memo is required when a difference is allocated.");

            var linesJson = Newtonsoft.Json.JsonConvert.SerializeObject(
                req.Lines.Select(l => new { l.SalesId, l.ApplyAmount, l.ShortDiscount }));

            return Uow.BankFeedTransactions.CreateInvoiceDeposit(req, linesJson, UserContext.EmpId);
        }

        public void Match(List<BankFeedMatchReq> reqs)
        {
            if (reqs == null || !reqs.Any())
                throw new Exception("Please select at least one transaction to match.");

            if (reqs.Any(r => !r.TxId.HasValue || !r.TxDetailId.HasValue))
                throw new Exception("Please select a transaction to match.");

            var groups = reqs.GroupBy(r => r.BankFeedTransactionId);

            foreach (var group in groups)
            {
                var json = Newtonsoft.Json.JsonConvert.SerializeObject(
                    group.Select(r => new { r.TxId, r.TxDetailId }));

                Uow.BankFeedTransactions.MatchTx(group.Key, json, UserContext.EmpId);
            }
        }

        /// <summary>
        /// Reverses a transaction Bank Feed created: deletes the payment, restores the bill
        /// balances and journal, and returns the bank row to Pending.
        /// </summary>
        /// <summary>
        /// Projected to id + name + default account only: the picker needs nothing else, and
        /// returning the whole Payee entity would drag 64 columns of unrelated master data
        /// into a lookup.
        /// </summary>
        public BankFeedChargePayee? GetLastChargePayee()
        {
            return Uow.BankFeedSources.GetLastChargePayee();
        }

        public void ReverseGenerated(BankFeedReverseReq req)
        {
            if (!Uow.BankFeedSources.HasActiveSource(req.BankFeedTransactionId))
                throw new Exception("This bank feed row has no transaction created by Bank Feed to reverse.");

            Uow.BankFeedSources.ReverseGenerated(
                req.BankFeedTransactionId, req.ReverseReason, UserContext.EmpId);
        }

        public int Unmatch(BankFeedBulkActionReq req)
        {
            if (req.BankFeedTransactionIds == null || !req.BankFeedTransactionIds.Any())
                throw new Exception("Please select at least one transaction.");

            var transactions = Uow.BankFeedTransactions
                .Find(t => req.BankFeedTransactionIds.Contains(t.BankFeedTransactionId)
                          && t.Status == "Matched")
                .ToList();

            if (!transactions.Any())
                throw new Exception("No eligible transactions found to unmatch.");

            // Unmatch only detaches the link. On a row Bank Feed generated, that would leave the
            // payment alive and the row back at Pending — free to be paid a second time. Those
            // rows must go through Reverse, which deletes the payment as well.
            var generated = transactions
                .Where(t => Uow.BankFeedSources.HasActiveSource(t.BankFeedTransactionId))
                .ToList();

            if (generated.Any())
                throw new Exception(generated.Count == transactions.Count
                    ? "This transaction was created by Bank Feed. Use Reverse instead of Unmatch."
                    : $"{generated.Count} of the selected transactions were created by Bank Feed. Use Reverse on those instead of Unmatch.");

            foreach (var tx in transactions)
            {
                Uow.BankFeedTransactions.UnMatchTx(tx.BankFeedTransactionId);
            }

            return transactions.Count;
        }

        public int Exclude(BankFeedBulkExcludeReq req)
        {
            if (req.BankFeedTransactionIds == null || !req.BankFeedTransactionIds.Any())
                throw new Exception("Please select at least one transaction.");

            var transactions = Uow.BankFeedTransactions
                .Find(t => req.BankFeedTransactionIds.Contains(t.BankFeedTransactionId)
                          && t.Status != "Matched" && t.Status != "Excluded")
                .ToList();

            if (!transactions.Any())
                throw new Exception("No eligible transactions found to exclude.");

            foreach (var tx in transactions)
            {
                tx.Status = "Excluded";
                tx.ExcludeReason = req.ExcludeReason ?? "Excluded by user";
                Uow.BankFeedTransactions.Update(tx);
            }

            Uow.Commit();
            return transactions.Count;
        }

        public int UnExclude(BankFeedBulkActionReq req)
        {
            if (req.BankFeedTransactionIds == null || !req.BankFeedTransactionIds.Any())
                throw new Exception("Please select at least one transaction.");

            var transactions = Uow.BankFeedTransactions
                .Find(t => req.BankFeedTransactionIds.Contains(t.BankFeedTransactionId)
                          && t.Status == "Excluded")
                .ToList();

            if (!transactions.Any())
                throw new Exception("No eligible transactions found to un-exclude.");

            foreach (var tx in transactions)
            {
                tx.Status = "Pending";
                tx.ExcludeReason = null;
                Uow.BankFeedTransactions.Update(tx);
            }

            Uow.Commit();
            return transactions.Count;
        }

        public int Delete(BankFeedBulkActionReq req)
        {
            if (req.BankFeedTransactionIds == null || !req.BankFeedTransactionIds.Any())
                throw new Exception("Please select at least one transaction.");

            var transactions = Uow.BankFeedTransactions
                .Find(t => req.BankFeedTransactionIds.Contains(t.BankFeedTransactionId)
                          && t.Status == "Excluded")
                .ToList();

            if (!transactions.Any())
                throw new Exception("No eligible transactions found to delete.");

            foreach (var tx in transactions)
            {
                Uow.BankFeedTransactions.Remove(tx);
            }

            Uow.Commit();
            return transactions.Count;
        }

        private BankFeedAccount EnsureBankFeedAccount(int accountId)
        {
            var existing = Uow.BankFeedAccounts.GetByAccountId(accountId);
            if (existing != null)
                return existing;

            var account = Uow.Accounts.GetById(accountId);
            if (account == null)
                throw new Exception("Selected account was not found.");

            var created = new BankFeedAccount
            {
                AccountId = accountId,
                AccountNickname = account.AccountName,
                ImportFormat = "CSV",
                IsActive = true
            };

            Uow.BankFeedAccounts.Add(created);
            Uow.Commit();
            return created;
        }

        private static string GetTempFilePath(string token)
        {
            return Path.Combine(TempRoot, $"{token}.csv");
        }

        private static List<List<string>> ReadRawRows(string path)
        {
            var rows = new List<List<string>>();
            using var parser = new TextFieldParser(path);
            parser.SetDelimiters(",");
            parser.HasFieldsEnclosedInQuotes = true;

            while (!parser.EndOfData)
            {
                rows.Add(parser.ReadFields()?.ToList() ?? new List<string>());
            }

            return rows;
        }

        private static BankFeedCsvColumnMap GuessMap(IReadOnlyList<string> headerRow)
        {
            var map = new BankFeedCsvColumnMap();
            var foundDate = false;
            var foundDesc = false;

            for (var i = 0; i < headerRow.Count; i++)
            {
                var header = NormalizeHeader(headerRow[i]);
                if (!foundDate && header.Contains("date"))
                {
                    map.DateColumnIndex = i;
                    foundDate = true;
                }
                else if (!foundDesc && (header.Contains("description") || header.Contains("memo") || header.Contains("details")))
                {
                    map.DescriptionColumnIndex = i;
                    foundDesc = true;
                }
                else if (header.Contains("reference") || header == "ref")
                {
                    map.ReferenceColumnIndex = i;
                }
                else if (header.Contains("check"))
                {
                    map.CheckNumberColumnIndex = i;
                }
                else if (header.Contains("credit"))
                {
                    map.CreditColumnIndex = i;
                }
                else if (header.Contains("debit"))
                {
                    map.DebitColumnIndex = i;
                }
                else if (header.Contains("amount"))
                {
                    map.AmountColumnIndex = i;
                }
            }

            if (map.CreditColumnIndex.HasValue || map.DebitColumnIndex.HasValue)
                map.AmountMode = "CreditDebit";

            return map;
        }

        private static string NormalizeHeader(string header)
        {
            return Regex.Replace(header ?? string.Empty, @"[^a-z0-9]", string.Empty, RegexOptions.IgnoreCase)
                .ToLowerInvariant();
        }

        private static void ValidateMap(BankFeedCsvColumnMap map)
        {
            if (map.DateColumnIndex < 0)
                throw new Exception("Please select the date column.");

            if (map.DescriptionColumnIndex < 0)
                throw new Exception("Please select the description column.");

            if (string.Equals(map.AmountMode, "CreditDebit", StringComparison.OrdinalIgnoreCase))
            {
                if (!map.CreditColumnIndex.HasValue && !map.DebitColumnIndex.HasValue)
                    throw new Exception("Please select the credit or debit columns.");
            }
            else if (!map.AmountColumnIndex.HasValue)
            {
                throw new Exception("Please select the amount column.");
            }
        }

        private static DateOnly ParseDate(string? value, string? dateFormat)
        {
            if (string.IsNullOrWhiteSpace(value))
                throw new Exception("Date value is required.");

            if (!string.IsNullOrWhiteSpace(dateFormat)
                && DateTime.TryParseExact(value.Trim(), dateFormat, CultureInfo.InvariantCulture, DateTimeStyles.None, out var exactDate))
            {
                return DateOnly.FromDateTime(exactDate);
            }

            if (DateTime.TryParse(value.Trim(), CultureInfo.InvariantCulture, DateTimeStyles.None, out var date))
                return DateOnly.FromDateTime(date);

            throw new Exception($"Invalid date value '{value}'.");
        }

        private static decimal ParseAmount(IReadOnlyList<string> row, BankFeedCsvColumnMap map)
        {
            if (string.Equals(map.AmountMode, "CreditDebit", StringComparison.OrdinalIgnoreCase))
            {
                var credit = map.CreditColumnIndex.HasValue ? TryParseNullableDecimal(GetValue(row, map.CreditColumnIndex.Value)) : null;
                var debit = map.DebitColumnIndex.HasValue ? TryParseNullableDecimal(GetValue(row, map.DebitColumnIndex.Value)) : null;

                if (credit.HasValue && credit.Value != 0)
                    return Math.Abs(credit.Value);

                if (debit.HasValue && debit.Value != 0)
                    return -Math.Abs(debit.Value);

                return 0;
            }

            var amount = TryParseNullableDecimal(GetValue(row, map.AmountColumnIndex!.Value));
            if (!amount.HasValue)
                throw new Exception("Amount value is required.");

            return amount.Value;
        }

        private static decimal? TryParseNullableDecimal(string? raw)
        {
            if (string.IsNullOrWhiteSpace(raw))
                return null;

            var normalized = raw.Trim()
                .Replace(",", string.Empty)
                .Replace("$", string.Empty)
                .Replace("(", "-")
                .Replace(")", string.Empty);

            if (decimal.TryParse(normalized, NumberStyles.Any, CultureInfo.InvariantCulture, out var amount))
                return amount;

            throw new Exception($"Invalid amount value '{raw}'.");
        }

        private static string? GetValue(IReadOnlyList<string> row, int index)
        {
            return index >= 0 && index < row.Count ? row[index] : null;
        }

        private static string? NullIfWhiteSpace(string? value)
        {
            return string.IsNullOrWhiteSpace(value) ? null : value.Trim();
        }

        private static void TryDeleteTempFile(string path)
        {
            try
            {
                if (File.Exists(path))
                    File.Delete(path);
            }
            catch
            {
            }
        }
    }
}
