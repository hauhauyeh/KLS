using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Data.SqlClient;
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

        private string GetItemImageRoot()
        {
            return ItemImageFileContract.ResolveItemImageRoot(_env, GetConfiguredItemImageRoot());
        }

        private string? GetConfiguredItemImageRoot()
        {
            return Uow.SystemSettings
                .Find(s => s.SettingKey == ItemImageFileContract.ItemImageRootSettingKey)
                .Select(s => s.SettingValue)
                .FirstOrDefault();
        }

        private string GetItemFolder(int itemId)
        {
            var folder = ItemImageFileContract.GetItemFolderPath(GetItemImageRoot(), itemId);
            Directory.CreateDirectory(folder);
            return folder;
        }

        private string GetItemFolderPath(int itemId)
        {
            return ItemImageFileContract.GetItemFolderPath(GetItemImageRoot(), itemId);
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

        internal static ItemImageList BuildImageDto(ItemImage entity, string baseUrl, int imageCount, string? itemFolderPath = null)
        {
            var itemId = entity.ItemId;
            var idx = entity.ImageIndex;
            var folderUrl = ItemImageFileContract.GetItemFolderUrl(baseUrl, itemId);

            var dto = new ItemImageList
            {
                ImageId = entity.ImageId,
                ItemId = itemId,
                ImageIndex = idx,
                SortOrder = entity.SortOrder,
                IsPrimary = entity.IsPrimary,
                IsProcessed = entity.IsProcessed,
                ImageCount = imageCount,
                OriginalWidth = entity.OriginalWidth,
                OriginalHeight = entity.OriginalHeight,
                EffectiveSourceWidth = entity.EffectiveSourceWidth,
                EffectiveSourceHeight = entity.EffectiveSourceHeight,
            };

            // URLs populated only when the actual file exists (flag-based, no inference)
            if (entity.Has300) dto.ThumbnailUrl = ResolveProcessedDisplayUrl(itemFolderPath, folderUrl, idx, ItemImageFileContract.ThumbnailSize);
            if (entity.Has900) dto.Url900 = ResolveProcessedDisplayUrl(itemFolderPath, folderUrl, idx, ItemImageFileContract.WebSize);
            if (entity.Has1600) dto.Url1600 = ResolveProcessedDisplayUrl(itemFolderPath, folderUrl, idx, ItemImageFileContract.HighResolutionSize);
            if (entity.Has2200) dto.Url2200 = ResolveProcessedDisplayUrl(itemFolderPath, folderUrl, idx, ItemImageFileContract.MarketplaceSize);
            if (entity.Has1200) dto.Url1200 = ResolveProcessedDisplayUrl(itemFolderPath, folderUrl, idx, ItemImageFileContract.LegacyWebSize);
            if (entity.Has2000) dto.Url2000 = ResolveProcessedDisplayUrl(itemFolderPath, folderUrl, idx, ItemImageFileContract.LegacyLargeSize);
            if (entity.HasNoBg300) dto.NoBgThumbnailUrl = ResolveNoBackgroundDisplayUrl(itemFolderPath, folderUrl, idx, ItemImageFileContract.ThumbnailSize);
            if (entity.HasNoBg900) dto.NoBg900Url = ResolveNoBackgroundDisplayUrl(itemFolderPath, folderUrl, idx, ItemImageFileContract.WebSize);
            if (entity.HasNoBg1200) dto.NoBg1200Url = ResolveNoBackgroundDisplayUrl(itemFolderPath, folderUrl, idx, ItemImageFileContract.LegacyWebSize);
            if (!string.IsNullOrEmpty(entity.OriginalExtension))
                dto.OriginalUrl = $"{folderUrl}/{ItemImageFileContract.GetOriginalFileName(idx, entity.OriginalExtension)}";

            return dto;
        }

        internal static string ResolveProcessedDisplayUrl(string? itemFolderPath, string folderUrl, int imageIndex, int size)
        {
            return ResolveDisplayUrl(
                itemFolderPath,
                folderUrl,
                ItemImageFileContract.GetProcessedDisplayFileNames(imageIndex, size),
                ItemImageFileContract.GetProcessedFileName(imageIndex, size));
        }

        private static string ResolveNoBackgroundDisplayUrl(string? itemFolderPath, string folderUrl, int imageIndex, int size)
        {
            return ResolveDisplayUrl(
                itemFolderPath,
                folderUrl,
                ItemImageFileContract.GetNoBackgroundDisplayFileNames(imageIndex, size),
                ItemImageFileContract.GetNoBackgroundFileName(imageIndex, size));
        }

        private static string ResolveDisplayUrl(
            string? itemFolderPath,
            string folderUrl,
            IEnumerable<string> candidateFileNames,
            string fallbackFileName)
        {
            if (!string.IsNullOrWhiteSpace(itemFolderPath))
            {
                foreach (var fileName in candidateFileNames)
                {
                    if (File.Exists(Path.Combine(itemFolderPath, fileName)))
                        return $"{folderUrl}/{fileName}";
                }
            }

            return $"{folderUrl}/{fallbackFileName}";
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

        private static Image CropMaxCenteredSquare(Image source)
        {
            var size = Math.Min(source.Width, source.Height);
            var x = (source.Width - size) / 2;
            var y = (source.Height - size) / 2;

            return source.Clone(ctx => ctx.Crop(new Rectangle(x, y, size, size)));
        }

        private static Image CreateEffectiveSquareSource(
            Image original,
            decimal? cropXRatio,
            decimal? cropYRatio,
            decimal? cropSizeRatio)
        {
            if (!cropXRatio.HasValue || !cropYRatio.HasValue || !cropSizeRatio.HasValue)
                return CropMaxCenteredSquare(original);

            var paddedSize = (int)Math.Ceiling(Math.Max(original.Width, original.Height) * 1.10);
            paddedSize = Math.Max(1, paddedSize);
            var offsetX = (paddedSize - original.Width) / 2;
            var offsetY = (paddedSize - original.Height) / 2;

            using var padded = new Image<SixLabors.ImageSharp.PixelFormats.Rgba32>(paddedSize, paddedSize);
            using var rgba = original.CloneAs<SixLabors.ImageSharp.PixelFormats.Rgba32>();
            padded.Mutate(ctx => ctx.DrawImage(rgba, new Point(offsetX, offsetY), 1f));

            var cropSize = Math.Max(1, (int)Math.Round(paddedSize * (double)cropSizeRatio.Value));
            cropSize = Math.Min(cropSize, paddedSize);
            var x = (int)Math.Round(paddedSize * (double)cropXRatio.Value);
            var y = (int)Math.Round(paddedSize * (double)cropYRatio.Value);
            x = Math.Clamp(x, 0, Math.Max(0, paddedSize - cropSize));
            y = Math.Clamp(y, 0, Math.Max(0, paddedSize - cropSize));

            return padded.Clone(ctx => ctx.Crop(new Rectangle(x, y, cropSize, cropSize)));
        }

        private static GeneratedImageVersions GenerateWithBackgroundVersions(
            Image original,
            string itemFolder,
            int imageIndex,
            decimal? cropXRatio,
            decimal? cropYRatio,
            decimal? cropSizeRatio,
            bool writeFiles = true)
        {
            using var effectiveSource = CreateEffectiveSquareSource(original, cropXRatio, cropYRatio, cropSizeRatio);
            var effectiveSize = Math.Min(effectiveSource.Width, effectiveSource.Height);
            var generatedSizes = new HashSet<int> { ItemImageFileContract.ThumbnailSize };

            foreach (var size in ItemImageFileContract.ActiveWithBackgroundSizes
                         .Concat(ItemImageFileContract.LegacyWithBackgroundSizes)
                         .Distinct()
                         .Where(size => size != ItemImageFileContract.ThumbnailSize))
            {
                if (ItemImageFileContract.CanGenerateSize(effectiveSize, size))
                    generatedSizes.Add(size);
            }

            if (writeFiles)
            {
                effectiveSource.Save(Path.Combine(itemFolder, ItemImageFileContract.GetTempCropFileName(imageIndex)), new PngEncoder());

                foreach (var size in generatedSizes)
                {
                    SaveResized(
                        effectiveSource,
                        Path.Combine(itemFolder, ItemImageFileContract.GetTempProcessedFileName(imageIndex, size)),
                        size);
                }
            }

            return new GeneratedImageVersions(
                original.Width,
                original.Height,
                effectiveSource.Width,
                effectiveSource.Height,
                generatedSizes.Contains(ItemImageFileContract.ThumbnailSize),
                generatedSizes.Contains(ItemImageFileContract.WebSize),
                generatedSizes.Contains(ItemImageFileContract.LegacyWebSize),
                generatedSizes.Contains(ItemImageFileContract.HighResolutionSize),
                generatedSizes.Contains(ItemImageFileContract.LegacyLargeSize),
                generatedSizes.Contains(ItemImageFileContract.MarketplaceSize));
        }

        private static void PublishWithBackgroundVersions(string itemFolder, int imageIndex, GeneratedImageVersions generated)
        {
            var generatedSizes = generated.GetGeneratedSizes().ToHashSet();

            CleanupOptimizedDisplaySidecars(itemFolder, imageIndex);
            File.Move(
                Path.Combine(itemFolder, ItemImageFileContract.GetTempCropFileName(imageIndex)),
                Path.Combine(itemFolder, ItemImageFileContract.GetCropFileName(imageIndex)),
                overwrite: true);

            foreach (var size in ItemImageFileContract.ActiveWithBackgroundSizes
                         .Concat(ItemImageFileContract.LegacyWithBackgroundSizes)
                         .Distinct())
            {
                var targetPath = Path.Combine(itemFolder, ItemImageFileContract.GetProcessedFileName(imageIndex, size));
                if (generatedSizes.Contains(size))
                {
                    File.Move(
                        Path.Combine(itemFolder, ItemImageFileContract.GetTempProcessedFileName(imageIndex, size)),
                        targetPath,
                        overwrite: true);
                }
                else
                {
                    TryDeleteFile(targetPath);
                }
            }
        }

        private static void ApplyGeneratedVersionFlags(ItemImage entity, GeneratedImageVersions generated)
        {
            entity.OriginalWidth = generated.OriginalWidth;
            entity.OriginalHeight = generated.OriginalHeight;
            entity.EffectiveSourceWidth = generated.EffectiveSourceWidth;
            entity.EffectiveSourceHeight = generated.EffectiveSourceHeight;
            entity.Has300 = generated.Has300;
            entity.Has900 = generated.Has900;
            entity.Has1200 = generated.Has1200;
            entity.Has1600 = generated.Has1600;
            entity.Has2000 = generated.Has2000;
            entity.Has2200 = generated.Has2200;
        }

        private static void ValidateCropRatios(decimal? cropXRatio, decimal? cropYRatio, decimal? cropSizeRatio)
        {
            var suppliedCount =
                (cropXRatio.HasValue ? 1 : 0)
                + (cropYRatio.HasValue ? 1 : 0)
                + (cropSizeRatio.HasValue ? 1 : 0);

            if (suppliedCount == 0) return;
            if (suppliedCount != 3)
                throw new ArgumentException("Crop ratios must include CropXRatio, CropYRatio, and CropSizeRatio.");

            var x = cropXRatio.Value;
            var y = cropYRatio.Value;
            var size = cropSizeRatio.Value;

            if (x < 0 || x > 1)
                throw new ArgumentException("CropXRatio must be between 0 and 1.");
            if (y < 0 || y > 1)
                throw new ArgumentException("CropYRatio must be between 0 and 1.");
            if (size <= 0 || size > 1)
                throw new ArgumentException("CropSizeRatio must be greater than 0 and no more than 1.");
            const decimal ratioTolerance = 0.000001m;
            if (x + size > 1 + ratioTolerance)
                throw new ArgumentException("Crop ratios exceed source width.");
            if (y + size > 1 + ratioTolerance)
                throw new ArgumentException("Crop ratios exceed source height.");
        }

        private static decimal? GetOptionalRatio(IReadOnlyList<decimal>? ratios, int index)
        {
            return ratios != null && ratios.Count > 0 ? ratios[index] : null;
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

        private async Task<(string stdout, string stderr)> RunPythonAsync(string scriptPath, string[] args, int timeoutMs = 300000)
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

            // Only override temp dirs. Don't override HOME/USERPROFILE in dev —
            // rembg caches its model in ~/.u2net/ and needs to find it.
            // For IIS deployment, uncomment HOME/USERPROFILE and pre-cache the model.
            psi.Environment["TEMP"] = pyCache;
            psi.Environment["TMP"] = pyCache;
            // psi.Environment["USERPROFILE"] = pyCache;  // IIS only
            // psi.Environment["HOME"] = pyCache;          // IIS only
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
            foreach (var fileName in ItemImageFileContract.GetTempFileNames(imageIndex))
                TryDeleteFile(Path.Combine(itemFolder, fileName));
        }

        private static void CleanupOptimizedDisplaySidecars(string itemFolder, int imageIndex)
        {
            foreach (var fileName in ItemImageFileContract.GetOptimizedDisplaySidecarFileNames(imageIndex))
                TryDeleteFile(Path.Combine(itemFolder, fileName));
        }

        private static void CleanupOptimizedNoBackgroundDisplaySidecars(string itemFolder, int imageIndex)
        {
            foreach (var fileName in ItemImageFileContract.GetOptimizedNoBackgroundDisplaySidecarFileNames(imageIndex))
                TryDeleteFile(Path.Combine(itemFolder, fileName));
        }

        private static void CleanupNoBackgroundFiles(string itemFolder, int imageIndex)
        {
            foreach (var size in ItemImageFileContract.ActiveNoBackgroundSizes
                         .Concat(ItemImageFileContract.LegacyNoBackgroundSizes)
                         .Distinct())
            {
                TryDeleteFile(Path.Combine(itemFolder, ItemImageFileContract.GetNoBackgroundFileName(imageIndex, size)));
            }

            CleanupOptimizedNoBackgroundDisplaySidecars(itemFolder, imageIndex);
        }

        private static void ClearNoBackgroundState(ItemImage entity)
        {
            entity.IsProcessed = false;
            entity.HasNoBg300 = false;
            entity.HasNoBg900 = false;
            entity.HasNoBg1200 = false;
        }

        private static IEnumerable<string> GetFlaggedFileNames(ItemImage image)
        {
            return ItemImageFileContract.GetRequiredFileNames(
                image.ImageIndex,
                image.OriginalExtension,
                ToFileFlags(image));
        }

        private static IEnumerable<string> GetOptionalCloneFileNames(ItemImage image)
        {
            yield return ItemImageFileContract.GetCropFileName(image.ImageIndex);

            foreach (var fileName in ItemImageFileContract.GetOptimizedDisplaySidecarFileNames(image.ImageIndex))
                yield return fileName;
        }

        private static ItemImageFileFlags ToFileFlags(ItemImage image)
        {
            return new ItemImageFileFlags(
                image.Has300,
                image.Has900,
                image.Has1200,
                image.Has1600,
                image.Has2000,
                image.HasNoBg300,
                image.HasNoBg900,
                image.HasNoBg1200);
        }

        private readonly record struct GeneratedImageVersions(
            int OriginalWidth,
            int OriginalHeight,
            int EffectiveSourceWidth,
            int EffectiveSourceHeight,
            bool Has300,
            bool Has900,
            bool Has1200,
            bool Has1600,
            bool Has2000,
            bool Has2200)
        {
            public IEnumerable<int> GetGeneratedSizes()
            {
                if (Has300) yield return ItemImageFileContract.ThumbnailSize;
                if (Has900) yield return ItemImageFileContract.WebSize;
                if (Has1200) yield return ItemImageFileContract.LegacyWebSize;
                if (Has1600) yield return ItemImageFileContract.HighResolutionSize;
                if (Has2000) yield return ItemImageFileContract.LegacyLargeSize;
                if (Has2200) yield return ItemImageFileContract.MarketplaceSize;
            }
        }

        private readonly record struct MarketplaceMigrationSource(
            string FilePath,
            string SourceType,
            bool AllowCropRatios);

        private List<ItemImage> GetSourceCloneImages(int sourceItemId)
        {
            return Uow.ItemImages
                .Find(x => x.ItemId == sourceItemId)
                .OrderBy(x => x.SortOrder)
                .ThenBy(x => x.ImageIndex)
                .ToList();
        }

        private void ValidateCloneImageFiles(int sourceItemId, List<ItemImage> images)
        {
            if (images.Count == 0) return;

            var sourceFolder = GetItemFolderPath(sourceItemId);
            if (!Directory.Exists(sourceFolder))
                throw new DirectoryNotFoundException($"Source image folder not found for item {sourceItemId}.");

            foreach (var image in images)
            {
                foreach (var fileName in GetFlaggedFileNames(image))
                {
                    var sourcePath = Path.Combine(sourceFolder, fileName);
                    if (!File.Exists(sourcePath))
                        throw new FileNotFoundException($"Source image file not found: {fileName}");
                }
            }
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
            var itemFolderPath = GetItemFolderPath(itemId);

            return records.Select(c => BuildImageDto(c, baseUrl, imageCount, itemFolderPath)).ToList();
        }

        public ItemImageList? GetPrimary(int itemId)
        {
            return GetList(itemId)?.FirstOrDefault(c => c.IsPrimary);
        }

        public ItemImage GetById(int imageId)
        {
            return Uow.ItemImages.GetById(imageId);
        }

        public ImageFileResult GetOriginalFile(int imageId)
        {
            var entity = Uow.ItemImages.GetById(imageId);
            if (entity == null) throw new Exception("Image not found.");
            if (string.IsNullOrWhiteSpace(entity.OriginalExtension))
                throw new Exception("Original image extension is missing.");

            var fileName = ItemImageFileContract.GetOriginalFileName(entity.ImageIndex, entity.OriginalExtension);
            var filePath = Path.Combine(GetItemFolderPath(entity.ItemId), fileName);
            if (!File.Exists(filePath))
                throw new FileNotFoundException($"Original image not found: {fileName}");

            return new ImageFileResult
            {
                FilePath = filePath,
                FileName = fileName,
                ContentType = GetImageContentType(entity.OriginalExtension)
            };
        }

        private static string GetImageContentType(string extension)
        {
            return extension.ToLowerInvariant() switch
            {
                ".jpg" or ".jpeg" => "image/jpeg",
                ".png" => "image/png",
                ".webp" => "image/webp",
                _ => "application/octet-stream"
            };
        }

        public void ValidateCloneImages(int sourceItemId)
        {
            var sourceImages = GetSourceCloneImages(sourceItemId);
            ValidateCloneImageFiles(sourceItemId, sourceImages);
        }

        public void CloneImages(int sourceItemId, int targetItemId)
        {
            if (sourceItemId <= 0) throw new ArgumentException("Source item is required.", nameof(sourceItemId));
            if (targetItemId <= 0) throw new ArgumentException("Target item is required.", nameof(targetItemId));
            if (sourceItemId == targetItemId) throw new ArgumentException("Source and target item cannot be the same.");

            var sourceImages = GetSourceCloneImages(sourceItemId);
            if (sourceImages.Count == 0) return;

            ValidateCloneImageFiles(sourceItemId, sourceImages);

            if (Uow.ItemImages.Find(x => x.ItemId == targetItemId).Any())
                throw new InvalidOperationException("Target item already has images.");

            var sourceFolder = GetItemFolderPath(sourceItemId);
            var targetFolder = GetItemFolder(targetItemId);
            var copiedFiles = new List<string>();
            var createdRows = new List<ItemImage>();

            try
            {
                foreach (var source in sourceImages)
                {
                    var clone = new ItemImage
                    {
                        ItemId = targetItemId,
                        ImageIndex = source.ImageIndex,
                        OriginalExtension = source.OriginalExtension,
                        SortOrder = source.SortOrder,
                        IsPrimary = source.IsPrimary,
                        IsProcessed = source.IsProcessed,
                        IsProcessing = false,
                        OriginalWidth = source.OriginalWidth,
                        OriginalHeight = source.OriginalHeight,
                        EffectiveSourceWidth = source.EffectiveSourceWidth,
                        EffectiveSourceHeight = source.EffectiveSourceHeight,
                        CropXRatio = source.CropXRatio,
                        CropYRatio = source.CropYRatio,
                        CropSizeRatio = source.CropSizeRatio,
                        Has300 = source.Has300,
                        Has900 = source.Has900,
                        Has1600 = source.Has1600,
                        Has2200 = source.Has2200,
                        Has1200 = source.Has1200,
                        Has2000 = source.Has2000,
                        HasNoBg300 = source.HasNoBg300,
                        HasNoBg900 = source.HasNoBg900,
                        HasNoBg1200 = source.HasNoBg1200
                    };

                    Uow.ItemImages.Add(clone);
                    createdRows.Add(clone);
                }

                Uow.Commit();

                foreach (var image in sourceImages)
                {
                    var fileNames = GetFlaggedFileNames(image)
                        .Concat(GetOptionalCloneFileNames(image)
                            .Where(fileName => File.Exists(Path.Combine(sourceFolder, fileName))))
                        .Distinct(StringComparer.OrdinalIgnoreCase);

                    foreach (var fileName in fileNames)
                    {
                        var sourcePath = Path.Combine(sourceFolder, fileName);
                        var targetPath = Path.Combine(targetFolder, fileName);
                        File.Copy(sourcePath, targetPath, overwrite: true);
                        copiedFiles.Add(targetPath);
                    }
                }
            }
            catch
            {
                foreach (var image in createdRows)
                {
                    Uow.ItemImages.Remove(image);
                }

                Uow.Commit();

                foreach (var file in copiedFiles)
                {
                    TryDeleteFile(file);
                }

                throw;
            }
        }

        public void Upload(ImageUploadReq uploadReq)
        {
            var itemFolder = GetItemFolder(uploadReq.ItemId);

            // Load current DB images for this item
            var dbImages = Uow.ItemImages
                .Find(x => x.ItemId == uploadReq.ItemId)
                .ToList();

            var order = uploadReq.Order ?? new List<int>();
            var files = uploadReq.CroppedFiles?.Any() == true
                ? uploadReq.CroppedFiles
                : uploadReq.files ?? new List<IFormFile>();
            var originalFiles = uploadReq.OriginalFiles ?? new List<IFormFile>();

            // If UI didn't send order, fallback: keep DB order + append new at end
            if (order.Count == 0)
            {
                order = dbImages.OrderBy(x => x.SortOrder).Select(x => x.ImageId).ToList();
                for (int i = 0; i < files.Count; i++) order.Add(0);
            }

            int zeroCount = order.Count(x => x == 0);
            if (zeroCount != files.Count)
                throw new Exception("Order placeholders (0) count must match uploaded files count.");
            if (originalFiles.Count > 0 && originalFiles.Count != zeroCount)
                throw new Exception("Original files count must match new image count.");

            if (uploadReq.CropXRatios?.Count > 0 && uploadReq.CropXRatios.Count != zeroCount)
                throw new ArgumentException("Crop X ratio count must match new image count.");
            if (uploadReq.CropYRatios?.Count > 0 && uploadReq.CropYRatios.Count != zeroCount)
                throw new ArgumentException("Crop Y ratio count must match new image count.");
            if (uploadReq.CropSizeRatios?.Count > 0 && uploadReq.CropSizeRatios.Count != zeroCount)
                throw new ArgumentException("Crop size ratio count must match new image count.");

            // Validate all IDs belong to this item
            var validIds = dbImages.Select(x => x.ImageId).ToHashSet();
            if (order.Any(id => id > 0 && !validIds.Contains(id)))
                throw new Exception("Invalid image id found in order list for this item.");

            // First image is the primary/default image.
            int primaryIndex = 0;

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
            int originalFileCursor = 0;

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
                var newFileIndex = fileCursor;
                var file = files[fileCursor++];
                var originalFile = originalFiles.Count > 0 ? originalFiles[originalFileCursor++] : file;
                var cropXRatio = GetOptionalRatio(uploadReq.CropXRatios, newFileIndex);
                var cropYRatio = GetOptionalRatio(uploadReq.CropYRatios, newFileIndex);
                var cropSizeRatio = GetOptionalRatio(uploadReq.CropSizeRatios, newFileIndex);
                ValidateCropRatios(cropXRatio, cropYRatio, cropSizeRatio);

                // Extension validation
                var ext = Path.GetExtension(originalFile.FileName).ToLowerInvariant();
                if (string.IsNullOrEmpty(ext) || !AllowedExtensions.Contains(ext))
                    throw new Exception($"Unsupported file format '{ext}'. Allowed: {string.Join(", ", AllowedExtensions)}");
                var cropExt = Path.GetExtension(file.FileName).ToLowerInvariant();
                if (string.IsNullOrEmpty(cropExt) || !AllowedExtensions.Contains(cropExt))
                    throw new Exception($"Unsupported cropped file format '{cropExt}'. Allowed: {string.Join(", ", AllowedExtensions)}");

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
                    CropXRatio = cropXRatio,
                    CropYRatio = cropYRatio,
                    CropSizeRatio = cropSizeRatio,
                };

                Uow.ItemImages.Add(entityNew);
                Uow.Commit(); // generate ImageId

                try
                {
                    // Save untouched original separately from the cropped display source.
                    var orgPath = Path.Combine(itemFolder, ItemImageFileContract.GetOriginalFileName(imageIndex, ext));
                    using (var stream = new FileStream(orgPath, FileMode.Create))
                    {
                        originalFile.CopyTo(stream);
                    }

                    GeneratedImageVersions generated;
                    using (var image = Image.Load(orgPath))
                    {
                        generated = GenerateWithBackgroundVersions(
                            image,
                            itemFolder,
                            imageIndex,
                            cropXRatio,
                            cropYRatio,
                            cropSizeRatio);
                    }

                    PublishWithBackgroundVersions(itemFolder, imageIndex, generated);
                    ApplyGeneratedVersionFlags(entityNew, generated);
                    Uow.ItemImages.Update(entityNew);
                }
                catch
                {
                    // Cleanup on failure
                    Uow.ItemImages.Remove(entityNew);
                    Uow.Commit();

                    TryDeleteFile(Path.Combine(itemFolder, ItemImageFileContract.GetOriginalFileName(imageIndex, ext)));
                    TryDeleteFile(Path.Combine(itemFolder, ItemImageFileContract.GetCropFileName(imageIndex)));
                    TryDeleteFile(Path.Combine(itemFolder, ItemImageFileContract.GetProcessedFileName(imageIndex, ItemImageFileContract.ThumbnailSize)));
                    TryDeleteFile(Path.Combine(itemFolder, ItemImageFileContract.GetProcessedFileName(imageIndex, ItemImageFileContract.WebSize)));
                    TryDeleteFile(Path.Combine(itemFolder, ItemImageFileContract.GetProcessedFileName(imageIndex, ItemImageFileContract.LegacyWebSize)));
                    TryDeleteFile(Path.Combine(itemFolder, ItemImageFileContract.GetProcessedFileName(imageIndex, ItemImageFileContract.HighResolutionSize)));
                    TryDeleteFile(Path.Combine(itemFolder, ItemImageFileContract.GetProcessedFileName(imageIndex, ItemImageFileContract.LegacyLargeSize)));
                    TryDeleteFile(Path.Combine(itemFolder, ItemImageFileContract.GetProcessedFileName(imageIndex, ItemImageFileContract.MarketplaceSize)));
                    CleanupTempFiles(itemFolder, imageIndex);

                    throw;
                }
            }

            Uow.Commit();
        }

        public void ReprocessOriginal(int imageId)
        {
            AcquireProcessingLock(imageId);

            try
            {
                var entity = Uow.ItemImages.GetById(imageId);
                if (entity == null) throw new Exception("Image not found.");
                if (string.IsNullOrWhiteSpace(entity.OriginalExtension))
                    throw new Exception("Original image extension is missing.");

                var itemFolder = GetItemFolder(entity.ItemId);
                var idx = entity.ImageIndex;
                var orgFileName = ItemImageFileContract.GetOriginalFileName(idx, entity.OriginalExtension);
                var orgPath = Path.Combine(itemFolder, orgFileName);
                if (!File.Exists(orgPath))
                    throw new FileNotFoundException($"Original image not found: {orgFileName}");

                CleanupTempFiles(itemFolder, idx);

                GeneratedImageVersions generated;
                using (var original = Image.Load(orgPath))
                {
                    generated = GenerateWithBackgroundVersions(
                        original,
                        itemFolder,
                        idx,
                        entity.CropXRatio,
                        entity.CropYRatio,
                        entity.CropSizeRatio);
                }

                PublishWithBackgroundVersions(itemFolder, idx, generated);
                ApplyGeneratedVersionFlags(entity, generated);
                CleanupNoBackgroundFiles(itemFolder, idx);
                ClearNoBackgroundState(entity);
                Uow.ItemImages.Update(entity);
                Uow.Commit();
            }
            finally
            {
                var entity = Uow.ItemImages.GetById(imageId);
                if (entity != null)
                {
                    CleanupTempFiles(GetItemFolder(entity.ItemId), entity.ImageIndex);
                }

                ReleaseProcessingLock(imageId);
            }
        }

        public void UpdateCrop(int imageId, ImageCropUpdateReq req)
        {
            if (req.CroppedFile == null || req.CroppedFile.Length == 0)
                throw new ArgumentException("Cropped image is required.");

            var cropExt = Path.GetExtension(req.CroppedFile.FileName).ToLowerInvariant();
            if (string.IsNullOrEmpty(cropExt) || !AllowedExtensions.Contains(cropExt))
                throw new ArgumentException($"Unsupported cropped file format '{cropExt}'. Allowed: {string.Join(", ", AllowedExtensions)}");
            ValidateCropRatios(req.CropXRatio, req.CropYRatio, req.CropSizeRatio);

            AcquireProcessingLock(imageId);

            try
            {
                var entity = Uow.ItemImages.GetById(imageId);
                if (entity == null) throw new Exception("Image not found.");

                var itemFolder = GetItemFolder(entity.ItemId);
                var idx = entity.ImageIndex;
                var originalPath = string.IsNullOrWhiteSpace(entity.OriginalExtension)
                    ? null
                    : Path.Combine(itemFolder, ItemImageFileContract.GetOriginalFileName(idx, entity.OriginalExtension));

                CleanupTempFiles(itemFolder, idx);

                GeneratedImageVersions generated;
                if (!string.IsNullOrWhiteSpace(originalPath) && File.Exists(originalPath))
                {
                    using var original = Image.Load(originalPath);
                    generated = GenerateWithBackgroundVersions(
                        original,
                        itemFolder,
                        idx,
                        req.CropXRatio,
                        req.CropYRatio,
                        req.CropSizeRatio);
                }
                else
                {
                    using var cropStream = req.CroppedFile.OpenReadStream();
                    using var cropped = Image.Load(cropStream);
                    generated = GenerateWithBackgroundVersions(cropped, itemFolder, idx, null, null, null);
                }

                PublishWithBackgroundVersions(itemFolder, idx, generated);
                ApplyGeneratedVersionFlags(entity, generated);
                CleanupNoBackgroundFiles(itemFolder, idx);
                ClearNoBackgroundState(entity);
                entity.CropXRatio = req.CropXRatio;
                entity.CropYRatio = req.CropYRatio;
                entity.CropSizeRatio = req.CropSizeRatio;
                Uow.ItemImages.Update(entity);
                Uow.Commit();
            }
            finally
            {
                var entity = Uow.ItemImages.GetById(imageId);
                if (entity != null)
                {
                    CleanupTempFiles(GetItemFolder(entity.ItemId), entity.ImageIndex);
                }

                ReleaseProcessingLock(imageId);
            }
        }

        public void Delete(int imageId)
        {
            var image = GetById(imageId);
            if (image == null) return;

            var itemId = image.ItemId;
            var idx = image.ImageIndex;
            var ext = image.OriginalExtension ?? ".png";
            var itemFolder = GetItemFolderPath(itemId);

            // Delete all files for this image (tolerant — ignore missing)
            TryDeleteFile(Path.Combine(itemFolder, ItemImageFileContract.GetOriginalFileName(idx, ext)));
            TryDeleteFile(Path.Combine(itemFolder, ItemImageFileContract.GetCropFileName(idx)));

            foreach (var size in ItemImageFileContract.ActiveWithBackgroundSizes.Concat(ItemImageFileContract.LegacyWithBackgroundSizes))
                TryDeleteFile(Path.Combine(itemFolder, ItemImageFileContract.GetProcessedFileName(idx, size)));

            foreach (var size in ItemImageFileContract.ActiveNoBackgroundSizes.Concat(ItemImageFileContract.LegacyNoBackgroundSizes))
                TryDeleteFile(Path.Combine(itemFolder, ItemImageFileContract.GetNoBackgroundFileName(idx, size)));

            CleanupOptimizedDisplaySidecars(itemFolder, idx);

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

                var orgFileName = ItemImageFileContract.GetOriginalFileName(idx, ext);
                var orgPath = Path.Combine(itemFolder, orgFileName);
                if (!File.Exists(orgPath))
                    throw new FileNotFoundException($"Original image not found: {orgFileName}");

                var tempFileName = ItemImageFileContract.GetTempPythonFileName(idx);
                var tempOutput = Path.Combine(itemFolder, tempFileName);

                await RunPythonAsync(
                    GetScriptPath("remove_bg_local.py"),
                    new[] { orgPath, tempOutput }
                );

                if (!File.Exists(tempOutput))
                    throw new Exception("Python background removal did not produce an output file.");

                var baseUrl = GetBaseUrl();
                var folderUrl = ItemImageFileContract.GetItemFolderUrl(baseUrl, entity.ItemId);

                return new ImageProcessResult
                {
                    ImageId = imageId,
                    ItemId = entity.ItemId,
                    ImageIndex = idx,
                    OriginalUrl = $"{folderUrl}/{orgFileName}",
                    PythonProcessedUrl = $"{folderUrl}/{tempFileName}"
                };
            }
            catch
            {
                // Clean up temp on failure
                var entity = Uow.ItemImages.GetById(imageId);
                if (entity != null)
                {
                    var folder = GetItemFolderPath(entity.ItemId);
                    TryDeleteFile(Path.Combine(folder, ItemImageFileContract.GetTempPythonFileName(entity.ImageIndex)));
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

                var orgFileName = ItemImageFileContract.GetOriginalFileName(idx, ext);
                var orgPath = Path.Combine(itemFolder, orgFileName);
                if (!File.Exists(orgPath))
                    throw new FileNotFoundException($"Original image not found: {orgFileName}");

                var tempFileName = ItemImageFileContract.GetTempApiFileName(idx);
                var tempOutput = Path.Combine(itemFolder, tempFileName);

                var apiKey = _appSettings.RemoveBgApiKey
                    ?? throw new Exception("RemoveBgApiKey not configured in appsettings.");

                await RunPythonAsync(
                    GetScriptPath("remove_bg_api.py"),
                    new[] { orgPath, tempOutput, apiKey }
                );

                if (!File.Exists(tempOutput))
                    throw new Exception("API background removal did not produce an output file.");

                var baseUrl = GetBaseUrl();
                var folderUrl = ItemImageFileContract.GetItemFolderUrl(baseUrl, entity.ItemId);

                return new ImageProcessResult
                {
                    ImageId = imageId,
                    ItemId = entity.ItemId,
                    ImageIndex = idx,
                    OriginalUrl = $"{folderUrl}/{orgFileName}",
                    ApiProcessedUrl = $"{folderUrl}/{tempFileName}"
                };
            }
            catch
            {
                var entity = Uow.ItemImages.GetById(imageId);
                if (entity != null)
                {
                    var folder = GetItemFolderPath(entity.ItemId);
                    TryDeleteFile(Path.Combine(folder, ItemImageFileContract.GetTempApiFileName(entity.ImageIndex)));
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
                    ClearNoBackgroundState(entity);
                    Uow.ItemImages.Update(entity);
                    Uow.Commit();
                    return;
                }

                // Determine no-bg source
                string nobgSource = req.SelectedVersion switch
                {
                    2 => Path.Combine(itemFolder, ItemImageFileContract.GetTempPythonFileName(idx)),
                    3 => Path.Combine(itemFolder, ItemImageFileContract.GetTempApiFileName(idx)),
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
                var nobg300 = Path.Combine(itemFolder, ItemImageFileContract.GetNoBackgroundFileName(idx, ItemImageFileContract.ThumbnailSize));
                var nobg900 = Path.Combine(itemFolder, ItemImageFileContract.GetNoBackgroundFileName(idx, ItemImageFileContract.WebSize));
                var nobg1200 = Path.Combine(itemFolder, ItemImageFileContract.GetNoBackgroundFileName(idx, ItemImageFileContract.LegacyWebSize));

                if (!File.Exists(nobg300) || !File.Exists(nobg900) || !File.Exists(nobg1200))
                    throw new Exception("create_sizes.py did not produce expected no-bg output files.");

                CleanupOptimizedNoBackgroundDisplaySidecars(itemFolder, idx);
                entity.IsProcessed = true;
                entity.HasNoBg300 = true;
                entity.HasNoBg900 = true;
                entity.HasNoBg1200 = true;
                Uow.ItemImages.Update(entity);
                Uow.Commit();
            }
            finally
            {
                // Always clean up temp files
                var entity = Uow.ItemImages.GetById(req.ImageId);
                if (entity != null)
                {
                    var folder = GetItemFolderPath(entity.ItemId);
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

                // 2026-06-25: dimension-aware master selection (replaces the old "-Org is the only
                // high-res source" logic). Clients keep their best resolution in different files --
                // KLS in -Org, ABC in the main file (ABC mains are full 1200x1200; only ~6% ship a
                // -Org). So instead of assuming -Org is largest, MEASURE every candidate (org / main
                // / 900) and treat the one with the greatest pixel dimensions as the master for ALL
                // generated sizes. Generate up to the master's native resolution only -- never
                // upscale (kills the old fake-2000 from a 1200 source). The master is also copied as
                // the canonical -org so every migrated image gets an OriginalUrl + a background-
                // removal source, not just the ones that shipped a -Org file.
                // (Prior -Org-only / main->300 / upscale logic preserved in git history.)

                // Gather every usable source candidate for this image (originals, main, 900 ref).
                var candidates = new List<(string filePath, string fileType)>();
                candidates.AddRange(files.Where(f => f.fileType == "org"));
                var mainFile = files.FirstOrDefault(f => f.fileType == "main");
                if (mainFile.filePath != null) candidates.Add(mainFile);
                var file900 = files.FirstOrDefault(f => f.fileType == "900");
                if (file900.filePath != null) candidates.Add(file900);

                // Pick the master = candidate with the largest max(width,height). Image.Identify
                // reads only the header (cheap). Tie -> prefer an -Org file (truest "original").
                string? masterPath = null;
                int masterMax = 0;
                foreach (var c in candidates)
                {
                    try
                    {
                        var info = Image.Identify(c.filePath);
                        int m = Math.Max(info.Width, info.Height);
                        if (m > masterMax || (m == masterMax && c.fileType == "org"))
                        {
                            masterMax = m;
                            masterPath = c.filePath;
                        }
                    }
                    catch (Exception ex)
                    {
                        result.Warnings.Add($"ItemId {itemId} idx {imageIndex}: cannot read {Path.GetFileName(c.filePath)}: {ex.Message}");
                    }
                }

                // No decodable source -> nothing to migrate for this image.
                if (masterPath == null)
                {
                    result.Warnings.Add($"ItemId {itemId} idx {imageIndex}: no decodable source, skipped");
                    result.Skipped++;
                    continue;
                }

                // Copy the master as the canonical original (preserve its format).
                var orgExt = Path.GetExtension(masterPath).ToLowerInvariant();
                File.Copy(masterPath, Path.Combine(itemFolder, ItemImageFileContract.GetOriginalFileName(imageIndex, orgExt)), overwrite: true);

                // Generate sizes from the master: 300 always; 1200/2000 only when the master is
                // natively big enough -- no upscaling above native resolution.
                bool has300 = false, has1200 = false, has2000 = false;
                try
                {
                    using var image = Image.Load(masterPath);
                    SaveResized(image, Path.Combine(itemFolder, ItemImageFileContract.GetProcessedFileName(imageIndex, ItemImageFileContract.ThumbnailSize)), ItemImageFileContract.ThumbnailSize);
                    has300 = true;
                    if (ItemImageFileContract.CanGenerateSize(masterMax, ItemImageFileContract.LegacyWebSize))
                    {
                        SaveResized(image, Path.Combine(itemFolder, ItemImageFileContract.GetProcessedFileName(imageIndex, ItemImageFileContract.LegacyWebSize)), ItemImageFileContract.LegacyWebSize);
                        has1200 = true;
                    }
                    if (ItemImageFileContract.CanGenerateSize(masterMax, ItemImageFileContract.LegacyLargeSize))
                    {
                        SaveResized(image, Path.Combine(itemFolder, ItemImageFileContract.GetProcessedFileName(imageIndex, ItemImageFileContract.LegacyLargeSize)), ItemImageFileContract.LegacyLargeSize);
                        has2000 = true;
                    }
                }
                catch (Exception ex)
                {
                    result.Warnings.Add($"ItemId {itemId} idx {imageIndex}: resize failed: {ex.Message}");
                }

                // Keep the -900 as a raw reference copy (unchanged behavior).
                if (file900.filePath != null)
                {
                    var srcExt = Path.GetExtension(file900.filePath).ToLowerInvariant();
                    File.Copy(file900.filePath, Path.Combine(itemFolder, ItemImageFileContract.GetRawImportedReferenceFileName(imageIndex, srcExt)), overwrite: true);
                }

                // No 300 produced (resize failed) -> clean up + skip the DB row.
                if (!has300)
                {
                    TryDeleteFile(Path.Combine(itemFolder, ItemImageFileContract.GetOriginalFileName(imageIndex, orgExt)));
                    result.Warnings.Add($"ItemId {itemId} idx {imageIndex}: no 300px produced, skipped + cleaned up");
                    result.Skipped++;
                    continue;
                }

                var entity = new ItemImage
                {
                    ItemId = itemId,
                    ImageIndex = imageIndex,
                    OriginalExtension = orgExt,
                    SortOrder = maxSortOrder,
                    IsPrimary = (maxSortOrder == 1 && !existingIndexes.Any()),
                    IsProcessed = false,
                    IsProcessing = false,
                    Has300 = true,
                    Has1200 = has1200,
                    Has2000 = has2000,
                };

                Uow.ItemImages.Add(entity);
                result.Imported++;
                anyNewForItem = true;
            }

            if (anyNewForItem)
                Uow.Commit();
        }

        public MigrationResult GenerateMissingMarketplaceVersions(ItemImageVersionMigrationReq req)
        {
            req ??= new ItemImageVersionMigrationReq();
            if (req.Limit < 0)
                throw new ArgumentException("Limit cannot be negative.", nameof(req.Limit));

            var result = new MigrationResult { DryRun = req.DryRun };
            var configuredRoot = GetConfiguredItemImageRoot();
            var itemsRoot = ItemImageFileContract.ResolveItemImageRoot(_env, configuredRoot);
            var rootExists = Directory.Exists(itemsRoot);

            result.Details.Add($"Database: {GetConfiguredDatabaseName()}");
            result.Details.Add($"Configured {ItemImageFileContract.ItemImageRootSettingKey}: {configuredRoot ?? "(blank)"}");
            result.Details.Add($"Resolved item image root: {itemsRoot}");
            result.Details.Add($"Root exists: {rootExists}");
            result.Details.Add($"DryRun: {req.DryRun}; Limit: {req.Limit}; Force: {req.Force}");

            if (!rootExists)
            {
                result.Success = false;
                result.Warnings.Add("Items image root not found.");
                return result;
            }

            var allRecords = Uow.ItemImages
                .Find(_ => true)
                .OrderBy(x => x.ItemId)
                .ThenBy(x => x.ImageIndex)
                .ToList();
            result.TotalItemsFound = allRecords.Count;

            var records = req.Limit > 0 ? allRecords.Take(req.Limit).ToList() : allRecords;
            var can900 = 0;
            var can1600 = 0;
            var can2200 = 0;
            var updatedRows = 0;

            foreach (var entity in records)
            {
                result.ItemsProcessed++;
                var itemFolder = ItemImageFileContract.GetItemFolderPath(itemsRoot, entity.ItemId);
                if (!Directory.Exists(itemFolder))
                {
                    result.Skipped++;
                    result.Warnings.Add($"ItemId {entity.ItemId} idx {entity.ImageIndex}: item image folder not found.");
                    continue;
                }

                var source = FindMarketplaceMigrationSource(itemFolder, entity);
                if (source == null)
                {
                    result.Skipped++;
                    result.Warnings.Add($"ItemId {entity.ItemId} idx {entity.ImageIndex}: no usable source file found.");
                    continue;
                }

                try
                {
                    GeneratedImageVersions generated;
                    using (var image = Image.Load(source.Value.FilePath))
                    {
                        generated = GenerateWithBackgroundVersions(
                            image,
                            itemFolder,
                            entity.ImageIndex,
                            source.Value.AllowCropRatios ? entity.CropXRatio : null,
                            source.Value.AllowCropRatios ? entity.CropYRatio : null,
                            source.Value.AllowCropRatios ? entity.CropSizeRatio : null,
                            !req.DryRun);
                    }

                    if (generated.Has900) can900++;
                    if (generated.Has1600) can1600++;
                    if (generated.Has2200) can2200++;

                    result.Details.Add(
                        $"ItemId {entity.ItemId} idx {entity.ImageIndex}: source={source.Value.SourceType} {generated.OriginalWidth}x{generated.OriginalHeight}; effective={generated.EffectiveSourceWidth}x{generated.EffectiveSourceHeight}; can 900={generated.Has900}, 1600={generated.Has1600}, 2200={generated.Has2200}");

                    AddSizeWarnings(result, entity, generated);

                    var publishCount = req.DryRun
                        ? CountMissingActiveVersionFiles(itemFolder, entity.ImageIndex, generated, req.Force)
                        : PublishMissingActiveVersionFiles(itemFolder, entity.ImageIndex, generated, req.Force);

                    if (publishCount == 0)
                    {
                        result.AlreadyMigrated++;
                    }
                    else
                    {
                        result.Imported += publishCount;
                    }

                    if (!req.DryRun)
                    {
                        var changed = ApplyMarketplaceMigrationMetadata(entity, generated);
                        changed = ApplyFilesystemVersionFlags(entity, itemFolder) || changed;
                        if (changed)
                        {
                            Uow.ItemImages.Update(entity);
                            updatedRows++;
                        }
                    }
                }
                catch (Exception ex)
                {
                    result.Failures++;
                    result.Warnings.Add($"ItemId {entity.ItemId} idx {entity.ImageIndex}: generation failed: {ex.Message}");
                }
                finally
                {
                    CleanupTempFiles(itemFolder, entity.ImageIndex);
                }
            }

            if (!req.DryRun && updatedRows > 0)
                Uow.Commit();

            result.Details.Add($"Can produce 900: {can900}");
            result.Details.Add($"Can produce 1600: {can1600}");
            result.Details.Add($"Can produce 2200: {can2200}");
            result.Details.Add($"DB rows updated: {updatedRows}");
            return result;
        }

        private static MarketplaceMigrationSource? FindMarketplaceMigrationSource(string itemFolder, ItemImage entity)
        {
            var idx = entity.ImageIndex;
            var cropPath = Path.Combine(itemFolder, ItemImageFileContract.GetCropFileName(idx));
            if (File.Exists(cropPath))
                return new MarketplaceMigrationSource(cropPath, "crop", false);

            var originalPath = FindOriginalFile(itemFolder, idx, entity.OriginalExtension);
            if (originalPath != null)
                return new MarketplaceMigrationSource(originalPath, "original", HasCompleteCropRatios(entity));

            var size2000 = Path.Combine(itemFolder, ItemImageFileContract.GetProcessedFileName(idx, ItemImageFileContract.LegacyLargeSize));
            if (File.Exists(size2000))
                return new MarketplaceMigrationSource(size2000, "2000", false);

            var size1200 = Path.Combine(itemFolder, ItemImageFileContract.GetProcessedFileName(idx, ItemImageFileContract.LegacyWebSize));
            if (File.Exists(size1200))
                return new MarketplaceMigrationSource(size1200, "1200", false);

            var raw900 = FindRawImportedReferenceFile(itemFolder, idx);
            if (raw900 != null)
                return new MarketplaceMigrationSource(raw900, "raw-900", false);

            return null;
        }

        private static string? FindOriginalFile(string itemFolder, int imageIndex, string? originalExtension)
        {
            if (!string.IsNullOrWhiteSpace(originalExtension))
            {
                var originalPath = Path.Combine(itemFolder, ItemImageFileContract.GetOriginalFileName(imageIndex, originalExtension));
                if (File.Exists(originalPath))
                    return originalPath;
            }

            if (!Directory.Exists(itemFolder))
                return null;

            return Directory
                .EnumerateFiles(itemFolder, $"{imageIndex}-org.*")
                .FirstOrDefault(path => AllowedExtensions.Contains(Path.GetExtension(path)));
        }

        private static string? FindRawImportedReferenceFile(string itemFolder, int imageIndex)
        {
            if (!Directory.Exists(itemFolder))
                return null;

            return Directory
                .EnumerateFiles(itemFolder, $"{imageIndex}-900.*")
                .FirstOrDefault(path =>
                    !Path.GetFileName(path).Contains("-nobg", StringComparison.OrdinalIgnoreCase)
                    && AllowedExtensions.Contains(Path.GetExtension(path)));
        }

        private static bool HasCompleteCropRatios(ItemImage entity)
        {
            return entity.CropXRatio.HasValue
                && entity.CropYRatio.HasValue
                && entity.CropSizeRatio.HasValue;
        }

        private static int CountMissingActiveVersionFiles(
            string itemFolder,
            int imageIndex,
            GeneratedImageVersions generated,
            bool force)
        {
            return GetPublishableActiveVersionSizes(generated)
                .Count(size => force || !File.Exists(Path.Combine(itemFolder, ItemImageFileContract.GetProcessedFileName(imageIndex, size))));
        }

        private static int PublishMissingActiveVersionFiles(
            string itemFolder,
            int imageIndex,
            GeneratedImageVersions generated,
            bool force)
        {
            var count = 0;
            foreach (var size in GetPublishableActiveVersionSizes(generated))
            {
                var tempPath = Path.Combine(itemFolder, ItemImageFileContract.GetTempProcessedFileName(imageIndex, size));
                var targetPath = Path.Combine(itemFolder, ItemImageFileContract.GetProcessedFileName(imageIndex, size));
                if (!File.Exists(tempPath))
                    continue;

                if (!force && File.Exists(targetPath))
                    continue;

                CleanupOptimizedProcessedDisplaySidecars(itemFolder, imageIndex, size);
                File.Move(tempPath, targetPath, overwrite: force);
                count++;
            }

            return count;
        }

        private static void CleanupOptimizedProcessedDisplaySidecars(string itemFolder, int imageIndex, int size)
        {
            foreach (var extension in ItemImageFileContract.NormalDisplayExtensions.Where(e => e != ".png"))
                TryDeleteFile(Path.Combine(itemFolder, ItemImageFileContract.GetProcessedFileName(imageIndex, size, extension)));
        }

        private static IEnumerable<int> GetPublishableActiveVersionSizes(GeneratedImageVersions generated)
        {
            var generatedSizes = generated.GetGeneratedSizes().ToHashSet();
            foreach (var size in ItemImageFileContract.ActiveWithBackgroundSizes)
            {
                if (generatedSizes.Contains(size))
                    yield return size;
            }
        }

        private static void AddSizeWarnings(MigrationResult result, ItemImage entity, GeneratedImageVersions generated)
        {
            var effectiveSize = Math.Min(generated.EffectiveSourceWidth, generated.EffectiveSourceHeight);
            if (!generated.Has900)
                result.Warnings.Add($"ItemId {entity.ItemId} idx {entity.ImageIndex}: effective crop {effectiveSize}px is smaller than 900.");
            if (!generated.Has1600)
                result.Warnings.Add($"ItemId {entity.ItemId} idx {entity.ImageIndex}: effective crop {effectiveSize}px is smaller than 1600.");
            if (!generated.Has2200)
                result.Warnings.Add($"ItemId {entity.ItemId} idx {entity.ImageIndex}: effective crop {effectiveSize}px is smaller than 2200.");
        }

        private static bool ApplyMarketplaceMigrationMetadata(ItemImage entity, GeneratedImageVersions generated)
        {
            var changed = false;
            changed = SetIfChanged(entity.OriginalWidth, generated.OriginalWidth, v => entity.OriginalWidth = v) || changed;
            changed = SetIfChanged(entity.OriginalHeight, generated.OriginalHeight, v => entity.OriginalHeight = v) || changed;
            changed = SetIfChanged(entity.EffectiveSourceWidth, generated.EffectiveSourceWidth, v => entity.EffectiveSourceWidth = v) || changed;
            changed = SetIfChanged(entity.EffectiveSourceHeight, generated.EffectiveSourceHeight, v => entity.EffectiveSourceHeight = v) || changed;
            return changed;
        }

        private static bool ApplyFilesystemVersionFlags(ItemImage entity, string itemFolder)
        {
            var idx = entity.ImageIndex;
            var changed = false;

            changed = SetIfChanged(entity.Has300, File.Exists(Path.Combine(itemFolder, ItemImageFileContract.GetProcessedFileName(idx, ItemImageFileContract.ThumbnailSize))), v => entity.Has300 = v) || changed;
            changed = SetIfChanged(entity.Has900, File.Exists(Path.Combine(itemFolder, ItemImageFileContract.GetProcessedFileName(idx, ItemImageFileContract.WebSize))), v => entity.Has900 = v) || changed;
            changed = SetIfChanged(entity.Has1200, File.Exists(Path.Combine(itemFolder, ItemImageFileContract.GetProcessedFileName(idx, ItemImageFileContract.LegacyWebSize))), v => entity.Has1200 = v) || changed;
            changed = SetIfChanged(entity.Has1600, File.Exists(Path.Combine(itemFolder, ItemImageFileContract.GetProcessedFileName(idx, ItemImageFileContract.HighResolutionSize))), v => entity.Has1600 = v) || changed;
            changed = SetIfChanged(entity.Has2000, File.Exists(Path.Combine(itemFolder, ItemImageFileContract.GetProcessedFileName(idx, ItemImageFileContract.LegacyLargeSize))), v => entity.Has2000 = v) || changed;
            changed = SetIfChanged(entity.Has2200, File.Exists(Path.Combine(itemFolder, ItemImageFileContract.GetProcessedFileName(idx, ItemImageFileContract.MarketplaceSize))), v => entity.Has2200 = v) || changed;
            changed = SetIfChanged(entity.HasNoBg300, File.Exists(Path.Combine(itemFolder, ItemImageFileContract.GetNoBackgroundFileName(idx, ItemImageFileContract.ThumbnailSize))), v => entity.HasNoBg300 = v) || changed;
            changed = SetIfChanged(entity.HasNoBg900, File.Exists(Path.Combine(itemFolder, ItemImageFileContract.GetNoBackgroundFileName(idx, ItemImageFileContract.WebSize))), v => entity.HasNoBg900 = v) || changed;
            changed = SetIfChanged(entity.HasNoBg1200, File.Exists(Path.Combine(itemFolder, ItemImageFileContract.GetNoBackgroundFileName(idx, ItemImageFileContract.LegacyWebSize))), v => entity.HasNoBg1200 = v) || changed;

            return changed;
        }

        private static bool SetIfChanged<T>(T current, T next, Action<T> apply)
        {
            if (EqualityComparer<T>.Default.Equals(current, next))
                return false;

            apply(next);
            return true;
        }

        private static string GetConfiguredDatabaseName()
        {
            try
            {
                return new SqlConnectionStringBuilder(Constants.ConnectionString).InitialCatalog;
            }
            catch
            {
                return "(unknown)";
            }
        }

        /// <summary>
        /// File-based backfill: scans item folders on disk and sets Has* flags
        /// based on actual file existence. No inference.
        /// </summary>
        public MigrationResult BackfillVersionFlags()
        {
            var result = new MigrationResult();
            var itemsRoot = GetItemImageRoot();

            if (!Directory.Exists(itemsRoot))
            {
                result.Warnings.Add("Items image root not found.");
                return result;
            }

            var allRecords = Uow.ItemImages.Find(_ => true).ToList();
            int updated = 0;

            foreach (var entity in allRecords)
            {
                var itemFolder = Path.Combine(itemsRoot, entity.ItemId.ToString());
                var idx = entity.ImageIndex;
                var ext = entity.OriginalExtension ?? ".png";

                bool h300 = File.Exists(Path.Combine(itemFolder, ItemImageFileContract.GetProcessedFileName(idx, ItemImageFileContract.ThumbnailSize)));
                bool h900 = File.Exists(Path.Combine(itemFolder, ItemImageFileContract.GetProcessedFileName(idx, ItemImageFileContract.WebSize)));
                bool h1200 = File.Exists(Path.Combine(itemFolder, ItemImageFileContract.GetProcessedFileName(idx, ItemImageFileContract.LegacyWebSize)));
                bool h1600 = File.Exists(Path.Combine(itemFolder, ItemImageFileContract.GetProcessedFileName(idx, ItemImageFileContract.HighResolutionSize)));
                bool h2000 = File.Exists(Path.Combine(itemFolder, ItemImageFileContract.GetProcessedFileName(idx, ItemImageFileContract.LegacyLargeSize)));
                bool h2200 = File.Exists(Path.Combine(itemFolder, ItemImageFileContract.GetProcessedFileName(idx, ItemImageFileContract.MarketplaceSize)));
                bool hNb300 = File.Exists(Path.Combine(itemFolder, ItemImageFileContract.GetNoBackgroundFileName(idx, ItemImageFileContract.ThumbnailSize)));
                bool hNb900 = File.Exists(Path.Combine(itemFolder, ItemImageFileContract.GetNoBackgroundFileName(idx, ItemImageFileContract.WebSize)));
                bool hNb1200 = File.Exists(Path.Combine(itemFolder, ItemImageFileContract.GetNoBackgroundFileName(idx, ItemImageFileContract.LegacyWebSize)));

                bool changed = false;
                if (entity.Has300 != h300) { entity.Has300 = h300; changed = true; }
                if (entity.Has900 != h900) { entity.Has900 = h900; changed = true; }
                if (entity.Has1200 != h1200) { entity.Has1200 = h1200; changed = true; }
                if (entity.Has1600 != h1600) { entity.Has1600 = h1600; changed = true; }
                if (entity.Has2000 != h2000) { entity.Has2000 = h2000; changed = true; }
                if (entity.Has2200 != h2200) { entity.Has2200 = h2200; changed = true; }
                if (entity.HasNoBg300 != hNb300) { entity.HasNoBg300 = hNb300; changed = true; }
                if (entity.HasNoBg900 != hNb900) { entity.HasNoBg900 = hNb900; changed = true; }
                if (entity.HasNoBg1200 != hNb1200) { entity.HasNoBg1200 = hNb1200; changed = true; }

                if (changed)
                {
                    Uow.ItemImages.Update(entity);
                    updated++;
                }

                result.ItemsProcessed++;
            }

            if (updated > 0) Uow.Commit();

            result.Imported = updated;
            result.Success = true;
            result.Details.Add($"Scanned {allRecords.Count} records, updated {updated} flags.");
            return result;
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
