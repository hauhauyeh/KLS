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

        public void Match(BankFeedMatchReq req)
        {
            if (!req.TxId.HasValue || !req.TxDetailId.HasValue)
                throw new Exception("Please select a transaction to match.");

            Uow.BankFeedTransactions.MatchTx(
                req.BankFeedTransactionId,
                req.TxId.Value,
                req.TxDetailId.Value,
                UserContext.EmpId);
        }

        public void Unmatch(BankFeedMatchReq req)
        {
            Uow.BankFeedTransactions.UnMatchTx(req.BankFeedTransactionId);
        }

        public void Exclude(BankFeedExcludeReq req)
        {
            var bankTx = Uow.BankFeedTransactions.GetByLongId(req.BankFeedTransactionId)
                ?? throw new Exception("Bank feed transaction was not found.");

            if (bankTx.Status == "Matched")
                throw new Exception("Please unmatch the transaction before excluding it.");

            bankTx.Status = "Excluded";
            bankTx.ExcludeReason = req.ExcludeReason;
            Uow.BankFeedTransactions.Update(bankTx);
            Uow.Commit();
        }

        public void UnExclude(long bankFeedTransactionId)
        {
            var bankTx = Uow.BankFeedTransactions.GetByLongId(bankFeedTransactionId)
                ?? throw new Exception("Bank feed transaction was not found.");

            if (bankTx.Status != "Excluded")
                throw new Exception("Only excluded transactions can be un-excluded.");

            bankTx.Status = "Pending";
            bankTx.ExcludeReason = null;
            Uow.BankFeedTransactions.Update(bankTx);
            Uow.Commit();
        }

        public void Delete(long bankFeedTransactionId)
        {
            var bankTx = Uow.BankFeedTransactions.GetByLongId(bankFeedTransactionId)
                ?? throw new Exception("Bank feed transaction was not found.");

            if (bankTx.Status == "Matched")
                throw new Exception("Matched transactions cannot be deleted. Please unmatch first.");

            if (bankTx.Status != "Excluded")
                throw new Exception("Only excluded transactions can be deleted.");

            Uow.BankFeedTransactions.Remove(bankTx);
            Uow.Commit();
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
