using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Hosting;
using System;
using System.Linq;
using System.Text.Json;

namespace KLS.Services
{
    /// <summary>
    /// Import Cost (plan item-import-cost-v2): vendor price list -> matched by
    /// ItemUnit.Barcode -> pending per-unit costs -> applied on the schedule
    /// day. The SPs own the rules (Item_ImportCostResolve is the single
    /// resolver behind preview and import; Item_ApplyPendingCost owns the
    /// guards). This service owns the file, the parse, and the counts.
    ///
    /// Separate from ItemService on purpose: that class already carries
    /// Twilio/HttpContext dependencies and has no IWebHostEnvironment.
    /// </summary>
    public class ItemCostImportService : BaseService, IItemCostImportService
    {
        private static readonly string[] AllowedExtensions = { ".csv", ".xlsx" };

        private readonly ImportFileStore _files;

        public ItemCostImportService(IUnitOfWork uow, IWebHostEnvironment hostingEnvironment) : base(uow)
        {
            _files = new ImportFileStore(hostingEnvironment, "_importcost");
        }

        #region --- Preview / Import ---

        public ItemCostImportPreviewRes Preview(ItemCostImportPreviewReq req)
        {
            RequireTier(req.Tier);

            var token = _files.Save(req.File!, AllowedExtensions);
            var path = _files.ExistingPathFor(token);

            try
            {
                var parsed = ItemCostImportFile.Parse(path);
                var preview = BuildPreview(parsed, ToJson(parsed), req.Tier);

                preview.UploadToken = token;
                preview.FileName = req.File!.FileName;

                return preview;
            }
            catch
            {
                // An unreadable file leaves nothing worth keeping.
                _files.TryDelete(path);
                throw;
            }
        }

        public ItemCostImportResult Import(ItemCostImportTokenReq req)
        {
            RequireTier(req.Tier);

            var path = _files.ExistingPathFor(req.UploadToken);

            // The file on disk is the source of truth, not whatever the client
            // last saw. The disabled button is UX; this (and the proc) is the control.
            var parsed = ItemCostImportFile.Parse(path);
            var rowsJson = ToJson(parsed);
            var preview = BuildPreview(parsed, rowsJson, req.Tier);

            if (preview.HasErrors)
                throw new ArgumentException(
                    $"The file still has {preview.InvalidCount} invalid row{(preview.InvalidCount == 1 ? "" : "s")}. Fix them and upload it again.");

            if (preview.UpdateCount == 0)
                throw new ArgumentException("Nothing to import: no row changes a cost.");

            var (importId, updatedUnitCount, notInFileCount) = Uow.ItemCostImports.Import(
                req.Tier,
                rowsJson,
                UserContext.EmpId,
                System.IO.Path.GetFileName(path),
                parsed.EffectiveFrom,
                parsed.EffectiveTo);

            // Committed by now. Cleanup failure must never turn that into an error.
            _files.TryDelete(path);

            return new ItemCostImportResult
            {
                ImportId = importId,
                UpdatedUnitCount = updatedUnitCount,
                UpdateCount = preview.UpdateCount,
                UnchangedCount = preview.UnchangedCount,
                NotFoundCount = preview.NotFoundCount,
                MarketCount = preview.MarketCount,
                SkippedCount = preview.SkippedCount,
                NotInFileCount = notInFileCount
            };
        }

        private ItemCostImportPreviewRes BuildPreview(ItemCostImportFile.Parsed parsed, string rowsJson, int tier)
        {
            if (parsed.Rows.Count == 0)
                throw new ArgumentException("No product rows were found in the file. Expected a PRODUCT / PRICE list (or a sheet with Code and Price columns).");

            var rows = Uow.ItemCostImports.Preview(tier, rowsJson, out var notInFileCount);

            var res = new ItemCostImportPreviewRes
            {
                Tier = tier,
                EffectiveFrom = parsed.EffectiveFrom,
                EffectiveTo = parsed.EffectiveTo,
                FileRowCount = parsed.Rows.Count,
                UpdateCount = rows.Count(r => r.Status == "Update"),
                UnchangedCount = rows.Count(r => r.Status == "Unchanged"),
                NotFoundCount = rows.Count(r => r.Status == "NotFound"),
                MarketCount = rows.Count(r => r.Status == "Market"),
                SkippedCount = rows.Count(r => r.Status == "Skipped"),
                InvalidCount = rows.Count(r => r.Status == "Invalid"),
                NotInFileCount = notInFileCount,
                Rows = rows
            };

            res.HasErrors = res.InvalidCount > 0;

            return res;
        }

        private static string ToJson(ItemCostImportFile.Parsed parsed)
        {
            // Property names are PascalCase by default, matching the SP's $.RowNo / $.Code / $.Description / $.Price.
            return JsonSerializer.Serialize(parsed.Rows);
        }

        #endregion

        #region --- Pending / Apply ---

        public ItemCostPendingStatusRes GetPendingStatus()
        {
            return new ItemCostPendingStatusRes
            {
                Status = Uow.ItemCostImports.GetPendingStatus(),
                PendingImports = Uow.ItemCostImports.GetPendingImports(),
                Reprice = Uow.ItemCostImports.GetRepriceStatus()
            };
        }

        public SalesRepriceResult RepriceOpenOrders()
        {
            return Uow.ItemCostImports.RepriceOpenOrders("MANUAL", UserContext.EmpId, applyId: null);
        }

        public ItemCostApplyResult ApplyPending()
        {
            var (applyId, unitCount) = Uow.ItemCostImports.ApplyPending(UserContext.EmpId);

            // 2026-08-29 (D6): cost roll is committed above; re-price flagged open orders now.
            // Per-order failures are reported in the result, never thrown - the Reprice Open
            // Orders button is the retry.
            var reprice = Uow.ItemCostImports.RepriceOpenOrders("MANUAL", UserContext.EmpId, applyId);

            return new ItemCostApplyResult
            {
                ApplyId = applyId,
                UnitCount = unitCount,
                Reprice = reprice
            };
        }

        #endregion

        private static void RequireTier(int tier)
        {
            if (tier != 1 && tier != 2)
                throw new ArgumentException("Tier must be 1 (pricing) or 2 (reference).");
        }
    }
}
