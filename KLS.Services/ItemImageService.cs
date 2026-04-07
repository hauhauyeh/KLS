using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Options;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats.Png;
using SixLabors.ImageSharp.Processing;
using System.Diagnostics;
using System.Text;

namespace KLS.Services
{
    public class ItemImageService : BaseService, IItemImageService
    {
        private readonly IWebHostEnvironment _env;
        private readonly IHttpContextAccessor _httpContextAccessor;
        private readonly AppSettings _appSettings;

        private static readonly HashSet<string> AllowedExtensions = new(StringComparer.OrdinalIgnoreCase)
        {
            ".jpg", ".jpeg", ".png", ".webp"
        };

        public ItemImageService(
            IUnitOfWork uow,
            IWebHostEnvironment env,
            IHttpContextAccessor httpContextAccessor,
            IOptions<AppSettings> appSettings) : base(uow)
        {
            _env = env;
            _httpContextAccessor = httpContextAccessor;
            _appSettings = appSettings.Value;
        }

        #region --- Helpers ---

        private string GetItemFolder(int itemId)
        {
            var folder = Path.Combine(_env.WebRootPath, "Images", "items", itemId.ToString());
            Directory.CreateDirectory(folder);
            return folder;
        }

        private string GetScriptPath(string scriptName)
        {
            return Path.Combine(_env.ContentRootPath, "Python", scriptName);
        }

        private string GetBaseUrl()
        {
            var request = _httpContextAccessor.HttpContext?.Request;
            if (request == null) return "";
            return $"{request.Scheme}://{request.Host}";
        }

        private static ItemImageList BuildImageDto(ItemImage entity, string baseUrl, int imageCount)
        {
            var itemId = entity.ItemId;
            var idx = entity.ImageIndex;
            var hasOriginal = !string.IsNullOrEmpty(entity.OriginalExtension);
            var folderUrl = $"{baseUrl}/Images/items/{itemId}";

            var dto = new ItemImageList
            {
                ImageId = entity.ImageId,
                ItemId = itemId,
                ImageIndex = idx,
                SortOrder = entity.SortOrder,
                IsPrimary = entity.IsPrimary,
                IsProcessed = entity.IsProcessed,
                ImageCount = imageCount,

                // 300 thumbnail — always present (created during upload or migration)
                ThumbnailUrl = $"{folderUrl}/{idx}-300.png",
            };

            // 1200, 2000, Original — only when original file exists (sizes were generated from it)
            if (hasOriginal)
            {
                dto.Url1200 = $"{folderUrl}/{idx}-1200.png";
                dto.Url2000 = $"{folderUrl}/{idx}-2000.png";
                dto.OriginalUrl = $"{folderUrl}/{idx}-org{entity.OriginalExtension}";
            }

            // No-bg URLs only when BG removal has been finalized
            if (entity.IsProcessed)
            {
                dto.NoBgThumbnailUrl = $"{folderUrl}/{idx}-300-nobg.png";
                dto.NoBg1200Url = $"{folderUrl}/{idx}-1200-nobg.png";
            }

            return dto;
        }

        private static void SaveResized(Image source, string outputPath, int targetSize)
        {
            // Clone and resize with transparent padding on square canvas.
            // Must convert to Rgba32 first — JPEG sources are Rgb24 (no alpha),
            // and ResizeMode.Pad with Color.Transparent would produce black padding without alpha channel.
            using var rgba = source.CloneAs<SixLabors.ImageSharp.PixelFormats.Rgba32>();
            rgba.Mutate(x => x.Resize(new ResizeOptions
            {
                Mode = ResizeMode.Pad,
                Size = new SixLabors.ImageSharp.Size(targetSize, targetSize),
                PadColor = SixLabors.ImageSharp.Color.Transparent
            }));
            rgba.Save(outputPath, new PngEncoder());
        }

        private void AcquireProcessingLock(int imageId)
        {
            var entity = Uow.ItemImages.GetById(imageId);
            if (entity == null) throw new Exception("Image not found.");
            if (entity.IsProcessing) throw new Exception("Image is already being processed.");
            entity.IsProcessing = true;
            Uow.ItemImages.Update(entity);
            Uow.Commit();
        }

        private void ReleaseProcessingLock(int imageId)
        {
            try
            {
                var entity = Uow.ItemImages.GetById(imageId);
                if (entity != null)
                {
                    entity.IsProcessing = false;
                    Uow.ItemImages.Update(entity);
                    Uow.Commit();
                }
            }
            catch { /* best effort */ }
        }

        private async Task<(string stdout, string stderr)> RunPythonAsync(string scriptPath, string[] args, int timeoutMs = 60000)
        {
            var psi = new ProcessStartInfo
            {
                FileName = _appSettings.PythonPath ?? "python",
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true,
                WorkingDirectory = Path.GetDirectoryName(scriptPath)
            };

            // IIS-safe environment for Python cache
            var appData = Path.Combine(_env.ContentRootPath, "App_Data");
            Directory.CreateDirectory(appData);
            var pyCache = Path.Combine(appData, "python_cache");
            Directory.CreateDirectory(pyCache);

            psi.Environment["TEMP"] = pyCache;
            psi.Environment["TMP"] = pyCache;
            psi.Environment["USERPROFILE"] = pyCache;
            psi.Environment["HOME"] = pyCache;
            psi.Environment["XDG_CACHE_HOME"] = pyCache;

            psi.ArgumentList.Add(scriptPath);
            foreach (var arg in args)
                psi.ArgumentList.Add(arg);

            var stdOutSb = new StringBuilder();
            var stdErrSb = new StringBuilder();

            using var process = new Process { StartInfo = psi };

            process.OutputDataReceived += (_, e) =>
            {
                if (e.Data != null) stdOutSb.AppendLine(e.Data);
            };
            process.ErrorDataReceived += (_, e) =>
            {
                if (e.Data != null) stdErrSb.AppendLine(e.Data);
            };

            process.Start();
            process.BeginOutputReadLine();
            process.BeginErrorReadLine();

            if (!process.WaitForExit(timeoutMs))
            {
                try { process.Kill(true); } catch { }
                throw new Exception("Image processing timed out.");
            }

            // Flush async pipes
            await process.WaitForExitAsync();

            var stdout = stdOutSb.ToString();
            var stderr = stdErrSb.ToString();

            if (process.ExitCode != 0)
            {
                throw new Exception(
                    $"Python script failed (exit code {process.ExitCode}).\n" +
                    $"STDERR:\n{stderr}\nSTDOUT:\n{stdout}");
            }

            return (stdout, stderr);
        }

        private static void TryDeleteFile(string path)
        {
            try { if (File.Exists(path)) File.Delete(path); } catch { }
        }

        private static void CleanupTempFiles(string itemFolder, int imageIndex)
        {
            TryDeleteFile(Path.Combine(itemFolder, $"{imageIndex}-temp-python.png"));
            TryDeleteFile(Path.Combine(itemFolder, $"{imageIndex}-temp-api.png"));
        }

        #endregion

        #region --- Public Methods ---

        public IEnumerable<ItemImageList>? GetList(int itemId)
        {
            var baseUrl = GetBaseUrl();

            var records = Uow.ItemImages
                .Find(c => c.ItemId == itemId)
                .OrderBy(c => c.SortOrder)
                .ToList();

            if (!records.Any()) return new List<ItemImageList>();

            var imageCount = records.Count;

            return records.Select(c => BuildImageDto(c, baseUrl, imageCount)).ToList();
        }

        public ItemImageList? GetPrimary(int itemId)
        {
            return GetList(itemId)?.FirstOrDefault(c => c.IsPrimary);
        }

        public ItemImage GetById(int imageId)
        {
            return Uow.ItemImages.GetById(imageId);
        }

        public void Upload(ImageUploadReq uploadReq)
        {
            var itemFolder = GetItemFolder(uploadReq.ItemId);

            // Load current DB images for this item
            var dbImages = Uow.ItemImages
                .Find(x => x.ItemId == uploadReq.ItemId)
                .ToList();

            var order = uploadReq.Order ?? new List<int>();
            var files = uploadReq.files ?? new List<IFormFile>();

            // If UI didn't send order, fallback: keep DB order + append new at end
            if (order.Count == 0)
            {
                order = dbImages.OrderBy(x => x.SortOrder).Select(x => x.ImageId).ToList();
                for (int i = 0; i < files.Count; i++) order.Add(0);
            }

            int zeroCount = order.Count(x => x == 0);
            if (zeroCount != files.Count)
                throw new Exception("Order placeholders (0) count must match uploaded files count.");

            // Validate all IDs belong to this item
            var validIds = dbImages.Select(x => x.ImageId).ToHashSet();
            if (order.Any(id => id > 0 && !validIds.Contains(id)))
                throw new Exception("Invalid image id found in order list for this item.");

            // Decide primary index
            int primaryIndex;
            if (uploadReq.PrimaryOrderIndex.HasValue &&
                uploadReq.PrimaryOrderIndex.Value >= 0 &&
                uploadReq.PrimaryOrderIndex.Value < order.Count)
            {
                primaryIndex = uploadReq.PrimaryOrderIndex.Value;
            }
            else
            {
                var existingPrimary = dbImages.FirstOrDefault(x => x.IsPrimary);
                if (existingPrimary != null)
                {
                    int idx = order.FindIndex(x => x == existingPrimary.ImageId);
                    primaryIndex = idx >= 0 ? idx : 0;
                }
                else
                {
                    primaryIndex = 0;
                }
            }

            // Clear primary for all existing images
            foreach (var img in dbImages.Where(x => x.IsPrimary))
            {
                img.IsPrimary = false;
                Uow.ItemImages.Update(img);
            }
            Uow.Commit();

            // Determine next ImageIndex for new files
            int nextImageIndex = dbImages.Any() ? dbImages.Max(x => x.ImageIndex) + 1 : 1;

            int fileCursor = 0;

            for (int i = 0; i < order.Count; i++)
            {
                int sort = i + 1;
                bool isPrimary = (i == primaryIndex);

                if (order[i] > 0)
                {
                    // Existing image — update sort/primary only
                    int id = order[i];
                    var entity = dbImages.First(x => x.ImageId == id);

                    bool changed = false;
                    if (entity.SortOrder != sort) { entity.SortOrder = sort; changed = true; }
                    if (entity.IsPrimary != isPrimary) { entity.IsPrimary = isPrimary; changed = true; }
                    if (changed) Uow.ItemImages.Update(entity);

                    continue;
                }

                // New file
                var file = files[fileCursor++];

                // Extension validation
                var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
                if (string.IsNullOrEmpty(ext) || !AllowedExtensions.Contains(ext))
                    throw new Exception($"Unsupported file format '{ext}'. Allowed: {string.Join(", ", AllowedExtensions)}");

                int imageIndex = nextImageIndex++;

                var entityNew = new ItemImage
                {
                    ItemId = uploadReq.ItemId,
                    ImageIndex = imageIndex,
                    OriginalExtension = ext,
                    SortOrder = sort,
                    IsPrimary = isPrimary,
                    IsProcessed = false,
                    IsProcessing = false,
                    // Bridge columns (for SPs + HomeService compatibility)
                    ThumbnailPath = $"/Images/items/{uploadReq.ItemId}/{imageIndex}-300.png",
                    RelativePath = $"/Images/items/{uploadReq.ItemId}/{imageIndex}-300.png",
                    FileName = $"{imageIndex}-org{ext}"
                };

                Uow.ItemImages.Add(entityNew);
                Uow.Commit(); // generate ImageId

                try
                {
                    // Save original
                    var orgPath = Path.Combine(itemFolder, $"{imageIndex}-org{ext}");
                    using (var stream = new FileStream(orgPath, FileMode.Create))
                    {
                        file.CopyTo(stream);
                    }

                    // Generate with-bg sizes using ImageSharp
                    using (var image = Image.Load(orgPath))
                    {
                        SaveResized(image, Path.Combine(itemFolder, $"{imageIndex}-300.png"), 300);
                        SaveResized(image, Path.Combine(itemFolder, $"{imageIndex}-1200.png"), 1200);
                        SaveResized(image, Path.Combine(itemFolder, $"{imageIndex}-2000.png"), 2000);
                    }
                }
                catch
                {
                    // Cleanup on failure
                    Uow.ItemImages.Remove(entityNew);
                    Uow.Commit();

                    TryDeleteFile(Path.Combine(itemFolder, $"{imageIndex}-org{ext}"));
                    TryDeleteFile(Path.Combine(itemFolder, $"{imageIndex}-300.png"));
                    TryDeleteFile(Path.Combine(itemFolder, $"{imageIndex}-1200.png"));
                    TryDeleteFile(Path.Combine(itemFolder, $"{imageIndex}-2000.png"));

                    throw;
                }
            }

            Uow.Commit();
        }

        public void Delete(int imageId)
        {
            var image = GetById(imageId);
            if (image == null) return;

            var itemId = image.ItemId;
            var idx = image.ImageIndex;
            var ext = image.OriginalExtension ?? ".png";
            var itemFolder = Path.Combine(_env.WebRootPath, "Images", "items", itemId.ToString());

            // Delete all files for this image (tolerant — ignore missing)
            TryDeleteFile(Path.Combine(itemFolder, $"{idx}-org{ext}"));
            TryDeleteFile(Path.Combine(itemFolder, $"{idx}-300.png"));
            TryDeleteFile(Path.Combine(itemFolder, $"{idx}-1200.png"));
            TryDeleteFile(Path.Combine(itemFolder, $"{idx}-2000.png"));
            TryDeleteFile(Path.Combine(itemFolder, $"{idx}-300-nobg.png"));
            TryDeleteFile(Path.Combine(itemFolder, $"{idx}-1200-nobg.png"));
            CleanupTempFiles(itemFolder, idx);

            // Remove DB record
            Uow.ItemImages.Remove(image);

            // Reassign primary if deleted was primary
            if (image.IsPrimary)
            {
                var next = Uow.ItemImages
                    .Find(c => c.ItemId == itemId && c.ImageId != imageId)
                    .OrderBy(c => c.SortOrder)
                    .FirstOrDefault();

                if (next != null)
                {
                    next.IsPrimary = true;
                    Uow.ItemImages.Update(next);
                }
            }

            Uow.Commit();

            // Remove folder if empty
            if (Directory.Exists(itemFolder) && !Directory.EnumerateFileSystemEntries(itemFolder).Any())
            {
                try { Directory.Delete(itemFolder); } catch { }
            }
        }

        public async Task<ImageProcessResult> ProcessBgLocal(int imageId)
        {
            AcquireProcessingLock(imageId);

            try
            {
                var entity = Uow.ItemImages.GetById(imageId);
                var itemFolder = GetItemFolder(entity.ItemId);
                var idx = entity.ImageIndex;
                var ext = entity.OriginalExtension ?? ".png";

                var orgPath = Path.Combine(itemFolder, $"{idx}-org{ext}");
                if (!File.Exists(orgPath))
                    throw new FileNotFoundException($"Original image not found: {idx}-org{ext}");

                var tempOutput = Path.Combine(itemFolder, $"{idx}-temp-python.png");

                await RunPythonAsync(
                    GetScriptPath("remove_bg_local.py"),
                    new[] { orgPath, tempOutput }
                );

                if (!File.Exists(tempOutput))
                    throw new Exception("Python background removal did not produce an output file.");

                var baseUrl = GetBaseUrl();
                var folderUrl = $"{baseUrl}/Images/items/{entity.ItemId}";

                return new ImageProcessResult
                {
                    ImageId = imageId,
                    ItemId = entity.ItemId,
                    ImageIndex = idx,
                    OriginalUrl = $"{folderUrl}/{idx}-org{ext}",
                    PythonProcessedUrl = $"{folderUrl}/{idx}-temp-python.png"
                };
            }
            catch
            {
                // Clean up temp on failure
                var entity = Uow.ItemImages.GetById(imageId);
                if (entity != null)
                {
                    var folder = Path.Combine(_env.WebRootPath, "Images", "items", entity.ItemId.ToString());
                    TryDeleteFile(Path.Combine(folder, $"{entity.ImageIndex}-temp-python.png"));
                }
                throw;
            }
            finally
            {
                ReleaseProcessingLock(imageId);
            }
        }

        public async Task<ImageProcessResult> ProcessBgApi(int imageId)
        {
            AcquireProcessingLock(imageId);

            try
            {
                var entity = Uow.ItemImages.GetById(imageId);
                var itemFolder = GetItemFolder(entity.ItemId);
                var idx = entity.ImageIndex;
                var ext = entity.OriginalExtension ?? ".png";

                var orgPath = Path.Combine(itemFolder, $"{idx}-org{ext}");
                if (!File.Exists(orgPath))
                    throw new FileNotFoundException($"Original image not found: {idx}-org{ext}");

                var tempOutput = Path.Combine(itemFolder, $"{idx}-temp-api.png");

                var apiKey = _appSettings.RemoveBgApiKey
                    ?? throw new Exception("RemoveBgApiKey not configured in appsettings.");

                await RunPythonAsync(
                    GetScriptPath("remove_bg_api.py"),
                    new[] { orgPath, tempOutput, apiKey }
                );

                if (!File.Exists(tempOutput))
                    throw new Exception("API background removal did not produce an output file.");

                var baseUrl = GetBaseUrl();
                var folderUrl = $"{baseUrl}/Images/items/{entity.ItemId}";

                return new ImageProcessResult
                {
                    ImageId = imageId,
                    ItemId = entity.ItemId,
                    ImageIndex = idx,
                    OriginalUrl = $"{folderUrl}/{idx}-org{ext}",
                    ApiProcessedUrl = $"{folderUrl}/{idx}-temp-api.png"
                };
            }
            catch
            {
                var entity = Uow.ItemImages.GetById(imageId);
                if (entity != null)
                {
                    var folder = Path.Combine(_env.WebRootPath, "Images", "items", entity.ItemId.ToString());
                    TryDeleteFile(Path.Combine(folder, $"{entity.ImageIndex}-temp-api.png"));
                }
                throw;
            }
            finally
            {
                ReleaseProcessingLock(imageId);
            }
        }

        public async Task Finalize(ImageFinalizeReq req)
        {
            AcquireProcessingLock(req.ImageId);

            try
            {
                var entity = Uow.ItemImages.GetById(req.ImageId);
                if (entity == null) throw new Exception("Image not found.");

                var itemFolder = GetItemFolder(entity.ItemId);
                var idx = entity.ImageIndex;

                if (req.SelectedVersion == 1)
                {
                    // User chose Original — no BG removal, no no-bg files
                    entity.IsProcessed = false;
                    Uow.ItemImages.Update(entity);
                    Uow.Commit();
                    return;
                }

                // Determine no-bg source
                string nobgSource = req.SelectedVersion switch
                {
                    2 => Path.Combine(itemFolder, $"{idx}-temp-python.png"),
                    3 => Path.Combine(itemFolder, $"{idx}-temp-api.png"),
                    _ => throw new Exception($"Invalid SelectedVersion: {req.SelectedVersion}")
                };

                if (!File.Exists(nobgSource))
                    throw new FileNotFoundException($"Selected BG-removed source not found.");

                // Run create_sizes.py for no-bg versions
                await RunPythonAsync(
                    GetScriptPath("create_sizes.py"),
                    new[] { nobgSource, itemFolder, idx.ToString() }
                );

                // Verify outputs
                var nobg300 = Path.Combine(itemFolder, $"{idx}-300-nobg.png");
                var nobg1200 = Path.Combine(itemFolder, $"{idx}-1200-nobg.png");

                if (!File.Exists(nobg300) || !File.Exists(nobg1200))
                    throw new Exception("create_sizes.py did not produce expected no-bg output files.");

                entity.IsProcessed = true;
                Uow.ItemImages.Update(entity);
                Uow.Commit();
            }
            finally
            {
                // Always clean up temp files
                var entity = Uow.ItemImages.GetById(req.ImageId);
                if (entity != null)
                {
                    var folder = Path.Combine(_env.WebRootPath, "Images", "items", entity.ItemId.ToString());
                    CleanupTempFiles(folder, entity.ImageIndex);
                }

                ReleaseProcessingLock(req.ImageId);
            }
        }

        public void UpdateSort(ItemImageSortReq req)
        {
            if (req.OrderedImageIds == null || req.OrderedImageIds.Count == 0)
                return;

            var images = Uow.ItemImages
                .Find(x => x.ItemId == req.ItemId)
                .ToList();

            if (images.Count == 0) return;

            var validIds = images.Select(x => x.ImageId).ToHashSet();
            if (req.OrderedImageIds.Any(id => !validIds.Contains(id)))
                throw new Exception("Invalid image id found for this item.");

            for (int i = 0; i < req.OrderedImageIds.Count; i++)
            {
                int id = req.OrderedImageIds[i];
                var img = images.First(x => x.ImageId == id);
                img.SortOrder = i + 1;
                Uow.ItemImages.Update(img);
            }

            Uow.Commit();
        }

        public void SetPrimary(int imageId)
        {
            var selected = Uow.ItemImages.GetById(imageId);
            if (selected == null) throw new Exception("Image not found.");

            var images = Uow.ItemImages
                .Find(x => x.ItemId == selected.ItemId)
                .ToList();

            foreach (var img in images)
            {
                bool shouldBePrimary = img.ImageId == imageId;
                if (img.IsPrimary != shouldBePrimary)
                {
                    img.IsPrimary = shouldBePrimary;
                    Uow.ItemImages.Update(img);
                }
            }

            Uow.Commit();
        }

        #endregion

        #region --- Migration ---

        /// <summary>
        /// One-time import of legacy images from a source folder into per-item folder structure.
        /// Supports dry-run (scan only), batch limit (staged rollout), and image-level idempotency.
        /// </summary>
        public MigrationResult MigrateLegacyImages(string sourceFolder, bool dryRun = false, int limit = 0)
        {
            var result = new MigrationResult { DryRun = dryRun };

            if (!Directory.Exists(sourceFolder))
                throw new DirectoryNotFoundException($"Source folder not found: {sourceFolder}");

            var allFiles = Directory.GetFiles(sourceFolder);

            // Group files by ItemId + sub-index
            var grouped = new Dictionary<int, Dictionary<int, List<(string filePath, string fileType)>>>();

            foreach (var filePath in allFiles)
            {
                var fileName = Path.GetFileNameWithoutExtension(filePath);
                var ext = Path.GetExtension(filePath).ToLowerInvariant();

                if (fileName.Contains("Temp", StringComparison.OrdinalIgnoreCase))
                {
                    result.Skipped++;
                    continue;
                }

                if (!AllowedExtensions.Contains(ext))
                {
                    result.Skipped++;
                    continue;
                }

                if (!TryParseLegacyFileName(fileName, out int itemId, out int subIndex, out string fileType))
                {
                    result.Skipped++;
                    continue;
                }

                if (!grouped.ContainsKey(itemId))
                    grouped[itemId] = new Dictionary<int, List<(string, string)>>();

                if (!grouped[itemId].ContainsKey(subIndex))
                    grouped[itemId][subIndex] = new List<(string, string)>();

                grouped[itemId][subIndex].Add((filePath, fileType));
            }

            result.TotalItemsFound = grouped.Count;

            // Process each item (respect limit)
            int itemsProcessedThisBatch = 0;

            // Pre-load valid ItemIds for orphan checking (one query, covers both dry-run and real run)
            var validItemIds = Uow.Items.Find(_ => true).Select(x => x.ItemId).ToHashSet();

            foreach (var (itemId, subGroups) in grouped.OrderBy(x => x.Key))
            {
                if (limit > 0 && itemsProcessedThisBatch >= limit) break;

                // Skip orphan images — ItemId doesn't exist in Item table
                if (!validItemIds.Contains(itemId))
                {
                    result.Warnings.Add($"ItemId {itemId}: not found in Item table, skipping (orphan)");
                    result.Skipped++;
                    continue;
                }

                try
                {
                    MigrateOneItem(itemId, subGroups, dryRun, result);
                }
                catch (Exception ex)
                {
                    result.Failures++;
                    result.Warnings.Add($"ItemId {itemId}: FAILED — {ex.Message}");
                }

                itemsProcessedThisBatch++;
                result.ItemsProcessed++;
            }

            result.Success = (result.Failures == 0);
            return result;
        }

        private void MigrateOneItem(int itemId, Dictionary<int, List<(string filePath, string fileType)>> subGroups, bool dryRun, MigrationResult result)
        {
            // Image-level idempotency
            var existingIndexes = Uow.ItemImages
                .Find(x => x.ItemId == itemId)
                .Select(x => x.ImageIndex)
                .ToHashSet();

            int maxSortOrder = existingIndexes.Any()
                ? Uow.ItemImages.Find(x => x.ItemId == itemId).Max(x => x.SortOrder)
                : 0;

            bool anyNewForItem = false;

            foreach (var (subIndex, files) in subGroups.OrderBy(x => x.Key))
            {
                int imageIndex = subIndex == 0 ? 1 : subIndex + 1;

                if (existingIndexes.Contains(imageIndex))
                {
                    result.AlreadyMigrated++;
                    continue;
                }

                if (dryRun)
                {
                    bool hasOrgDry = files.Any(f => f.fileType == "org");
                    bool hasMainDry = files.Any(f => f.fileType == "main");
                    result.Details.Add($"ItemId {itemId} idx {imageIndex}: main={hasMainDry}, org={hasOrgDry}, files={files.Count}");
                    result.Imported++;
                    continue;
                }

                var itemFolder = GetItemFolder(itemId);
                maxSortOrder++;
                string? orgExt = null;
                bool hasOrg = false;
                bool has300 = false;

                // Handle duplicate originals — prefer largest file
                var orgFiles = files.Where(f => f.fileType == "org").ToList();
                string? chosenOrgPath = null;
                if (orgFiles.Count > 1)
                {
                    chosenOrgPath = orgFiles
                        .OrderByDescending(f => new FileInfo(f.filePath).Length)
                        .First().filePath;
                    result.Warnings.Add($"ItemId {itemId} idx {imageIndex}: {orgFiles.Count} originals, chose largest");
                }
                else if (orgFiles.Count == 1)
                {
                    chosenOrgPath = orgFiles[0].filePath;
                }

                // Copy original as-is (preserve format)
                if (chosenOrgPath != null)
                {
                    orgExt = Path.GetExtension(chosenOrgPath).ToLowerInvariant();
                    File.Copy(chosenOrgPath, Path.Combine(itemFolder, $"{imageIndex}-org{orgExt}"), overwrite: true);
                    hasOrg = true;
                }

                // Convert main/display file to PNG
                var mainFile = files.FirstOrDefault(f => f.fileType == "main");
                if (mainFile.filePath != null)
                {
                    try
                    {
                        using var image = Image.Load(mainFile.filePath);
                        SaveResized(image, Path.Combine(itemFolder, $"{imageIndex}-300.png"), 300);
                        has300 = true;
                    }
                    catch (Exception ex)
                    {
                        result.Warnings.Add($"ItemId {itemId} idx {imageIndex}: main decode failed: {ex.Message}");
                    }
                }

                // Copy 900 as reference
                var file900 = files.FirstOrDefault(f => f.fileType == "900");
                if (file900.filePath != null)
                {
                    var srcExt = Path.GetExtension(file900.filePath).ToLowerInvariant();
                    File.Copy(file900.filePath, Path.Combine(itemFolder, $"{imageIndex}-900{srcExt}"), overwrite: true);
                }

                // If original exists but no main, generate 300 from original
                if (hasOrg && !has300)
                {
                    try
                    {
                        using var image = Image.Load(Path.Combine(itemFolder, $"{imageIndex}-org{orgExt}"));
                        SaveResized(image, Path.Combine(itemFolder, $"{imageIndex}-300.png"), 300);
                        has300 = true;
                    }
                    catch (Exception ex)
                    {
                        result.Warnings.Add($"ItemId {itemId} idx {imageIndex}: org decode failed: {ex.Message}");
                    }
                }

                // Skip DB record if no 300px was produced — clean up orphaned files
                if (!has300)
                {
                    if (hasOrg) TryDeleteFile(Path.Combine(itemFolder, $"{imageIndex}-org{orgExt}"));
                    if (file900.filePath != null)
                    {
                        var ext900 = Path.GetExtension(file900.filePath).ToLowerInvariant();
                        TryDeleteFile(Path.Combine(itemFolder, $"{imageIndex}-900{ext900}"));
                    }
                    result.Warnings.Add($"ItemId {itemId} idx {imageIndex}: no 300px produced, skipped + cleaned up");
                    result.Skipped++;
                    continue;
                }

                // Generate 1200 + 2000 ONLY if original exists
                if (hasOrg)
                {
                    try
                    {
                        using var image = Image.Load(Path.Combine(itemFolder, $"{imageIndex}-org{orgExt}"));
                        SaveResized(image, Path.Combine(itemFolder, $"{imageIndex}-1200.png"), 1200);
                        SaveResized(image, Path.Combine(itemFolder, $"{imageIndex}-2000.png"), 2000);
                    }
                    catch { /* 1200/2000 are non-critical */ }
                }

                var entity = new ItemImage
                {
                    ItemId = itemId,
                    ImageIndex = imageIndex,
                    OriginalExtension = hasOrg ? orgExt : null,
                    SortOrder = maxSortOrder,
                    IsPrimary = (maxSortOrder == 1 && !existingIndexes.Any()),
                    IsProcessed = false,
                    IsProcessing = false,
                    ThumbnailPath = $"/Images/items/{itemId}/{imageIndex}-300.png",
                    RelativePath = $"/Images/items/{itemId}/{imageIndex}-300.png",
                    FileName = hasOrg ? $"{imageIndex}-org{orgExt}" : null
                };

                Uow.ItemImages.Add(entity);
                result.Imported++;
                anyNewForItem = true;
            }

            if (anyNewForItem)
                Uow.Commit();
        }

        private static bool TryParseLegacyFileName(string fileName, out int itemId, out int subIndex, out string fileType)
        {
            itemId = 0;
            subIndex = 0;
            fileType = "main";

            // Remove known suffixes to find base
            var name = fileName;

            // Check for -Org suffix (case-insensitive)
            if (name.EndsWith("-Org", StringComparison.OrdinalIgnoreCase) ||
                name.EndsWith("-org", StringComparison.OrdinalIgnoreCase))
            {
                fileType = "org";
                name = name[..^4]; // strip "-Org"
            }
            else if (name.EndsWith("-900"))
            {
                fileType = "900";
                name = name[..^4]; // strip "-900"
            }

            // Now name should be "{ItemId}" or "{ItemId}-{subIndex}"
            var parts = name.Split('-');

            if (parts.Length == 1)
            {
                // Just ItemId
                return int.TryParse(parts[0], out itemId);
            }
            else if (parts.Length == 2)
            {
                // ItemId-subIndex (e.g. "421-1") OR ItemId-Org already stripped
                if (!int.TryParse(parts[0], out itemId)) return false;

                if (int.TryParse(parts[1], out subIndex))
                    return true;

                // parts[1] might be a non-numeric suffix we didn't handle — skip
                return false;
            }

            // More complex patterns (e.g. GUID-named files) — skip
            return false;
        }

        #endregion
    }

}
