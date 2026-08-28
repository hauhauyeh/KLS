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

        private string GetItemFolderPath(int itemId)
        {
            return Path.Combine(_env.WebRootPath, "Images", "items", itemId.ToString());
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

        internal static ItemImageList BuildImageDto(ItemImage entity, string baseUrl, int imageCount)
        {
            var itemId = entity.ItemId;
            var idx = entity.ImageIndex;
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
            };

            // URLs populated only when the actual file exists (flag-based, no inference)
            if (entity.Has300) dto.ThumbnailUrl = $"{folderUrl}/{idx}-300.png";
            if (entity.Has1200) dto.Url1200 = $"{folderUrl}/{idx}-1200.png";
            if (entity.Has2000) dto.Url2000 = $"{folderUrl}/{idx}-2000.png";
            if (entity.HasNoBg300) dto.NoBgThumbnailUrl = $"{folderUrl}/{idx}-300-nobg.png";
            if (entity.HasNoBg1200) dto.NoBg1200Url = $"{folderUrl}/{idx}-1200-nobg.png";
            if (!string.IsNullOrEmpty(entity.OriginalExtension))
                dto.OriginalUrl = $"{folderUrl}/{idx}-org{entity.OriginalExtension}";

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

        private static Image CropMaxCenteredSquare(Image source)
        {
            var size = Math.Min(source.Width, source.Height);
            var x = (source.Width - size) / 2;
            var y = (source.Height - size) / 2;

            return source.Clone(ctx => ctx.Crop(new Rectangle(x, y, size, size)));
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
            TryDeleteFile(Path.Combine(itemFolder, $"{imageIndex}-temp-python.png"));
            TryDeleteFile(Path.Combine(itemFolder, $"{imageIndex}-temp-api.png"));
            TryDeleteFile(Path.Combine(itemFolder, $"{imageIndex}-crop-temp.png"));
            TryDeleteFile(Path.Combine(itemFolder, $"{imageIndex}-300-temp.png"));
            TryDeleteFile(Path.Combine(itemFolder, $"{imageIndex}-1200-temp.png"));
            TryDeleteFile(Path.Combine(itemFolder, $"{imageIndex}-2000-temp.png"));
        }

        private static IEnumerable<string> GetFlaggedFileNames(ItemImage image)
        {
            var idx = image.ImageIndex;

            if (image.Has300) yield return $"{idx}-300.png";
            if (image.Has1200) yield return $"{idx}-1200.png";
            if (image.Has2000) yield return $"{idx}-2000.png";
            if (image.HasNoBg300) yield return $"{idx}-300-nobg.png";
            if (image.HasNoBg1200) yield return $"{idx}-1200-nobg.png";
            if (!string.IsNullOrWhiteSpace(image.OriginalExtension))
                yield return $"{idx}-org{image.OriginalExtension}";
        }

        private static IEnumerable<string> GetOptionalCloneFileNames(ItemImage image)
        {
            yield return $"{image.ImageIndex}-crop.png";
        }

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
                        Has300 = source.Has300,
                        Has1200 = source.Has1200,
                        Has2000 = source.Has2000,
                        HasNoBg300 = source.HasNoBg300,
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
                var file = files[fileCursor++];
                var originalFile = originalFiles.Count > 0 ? originalFiles[originalFileCursor++] : file;

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
                };

                Uow.ItemImages.Add(entityNew);
                Uow.Commit(); // generate ImageId

                try
                {
                    // Save untouched original separately from the cropped display source.
                    var orgPath = Path.Combine(itemFolder, $"{imageIndex}-org{ext}");
                    using (var stream = new FileStream(orgPath, FileMode.Create))
                    {
                        originalFile.CopyTo(stream);
                    }

                    var hasSeparateCropSource = originalFiles.Count > 0;
                    var cropPath = Path.Combine(itemFolder, $"{imageIndex}-crop.png");
                    if (hasSeparateCropSource)
                    {
                        using var croppedStream = file.OpenReadStream();
                        using var croppedImage = Image.Load(croppedStream);
                        croppedImage.Save(cropPath, new PngEncoder());
                    }

                    // Generate with-bg sizes using ImageSharp
                    var resizeSourcePath = hasSeparateCropSource ? cropPath : orgPath;
                    using (var image = Image.Load(resizeSourcePath))
                    {
                        SaveResized(image, Path.Combine(itemFolder, $"{imageIndex}-300.png"), 300);
                        SaveResized(image, Path.Combine(itemFolder, $"{imageIndex}-1200.png"), 1200);
                        SaveResized(image, Path.Combine(itemFolder, $"{imageIndex}-2000.png"), 2000);
                    }

                    // Set version flags based on actual files created
                    entityNew.Has300 = true;
                    entityNew.Has1200 = true;
                    entityNew.Has2000 = true;
                    Uow.ItemImages.Update(entityNew);
                }
                catch
                {
                    // Cleanup on failure
                    Uow.ItemImages.Remove(entityNew);
                    Uow.Commit();

                    TryDeleteFile(Path.Combine(itemFolder, $"{imageIndex}-org{ext}"));
                    TryDeleteFile(Path.Combine(itemFolder, $"{imageIndex}-crop.png"));
                    TryDeleteFile(Path.Combine(itemFolder, $"{imageIndex}-300.png"));
                    TryDeleteFile(Path.Combine(itemFolder, $"{imageIndex}-1200.png"));
                    TryDeleteFile(Path.Combine(itemFolder, $"{imageIndex}-2000.png"));

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
                var orgPath = Path.Combine(itemFolder, $"{idx}-org{entity.OriginalExtension}");
                if (!File.Exists(orgPath))
                    throw new FileNotFoundException($"Original image not found: {idx}-org{entity.OriginalExtension}");

                var cropTemp = Path.Combine(itemFolder, $"{idx}-crop-temp.png");
                var size300Temp = Path.Combine(itemFolder, $"{idx}-300-temp.png");
                var size1200Temp = Path.Combine(itemFolder, $"{idx}-1200-temp.png");
                var size2000Temp = Path.Combine(itemFolder, $"{idx}-2000-temp.png");

                CleanupTempFiles(itemFolder, idx);

                using (var original = Image.Load(orgPath))
                using (var cropped = CropMaxCenteredSquare(original))
                {
                    cropped.Save(cropTemp, new PngEncoder());
                    SaveResized(cropped, size300Temp, 300);
                    SaveResized(cropped, size1200Temp, 1200);
                    SaveResized(cropped, size2000Temp, 2000);
                }

                File.Move(cropTemp, Path.Combine(itemFolder, $"{idx}-crop.png"), overwrite: true);
                File.Move(size300Temp, Path.Combine(itemFolder, $"{idx}-300.png"), overwrite: true);
                File.Move(size1200Temp, Path.Combine(itemFolder, $"{idx}-1200.png"), overwrite: true);
                File.Move(size2000Temp, Path.Combine(itemFolder, $"{idx}-2000.png"), overwrite: true);

                entity.Has300 = true;
                entity.Has1200 = true;
                entity.Has2000 = true;
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

            AcquireProcessingLock(imageId);

            try
            {
                var entity = Uow.ItemImages.GetById(imageId);
                if (entity == null) throw new Exception("Image not found.");

                var itemFolder = GetItemFolder(entity.ItemId);
                var idx = entity.ImageIndex;
                var cropTemp = Path.Combine(itemFolder, $"{idx}-crop-temp.png");
                var size300Temp = Path.Combine(itemFolder, $"{idx}-300-temp.png");
                var size1200Temp = Path.Combine(itemFolder, $"{idx}-1200-temp.png");
                var size2000Temp = Path.Combine(itemFolder, $"{idx}-2000-temp.png");

                CleanupTempFiles(itemFolder, idx);

                using (var cropStream = req.CroppedFile.OpenReadStream())
                using (var cropped = Image.Load(cropStream))
                {
                    cropped.Save(cropTemp, new PngEncoder());
                    SaveResized(cropped, size300Temp, 300);
                    SaveResized(cropped, size1200Temp, 1200);
                    SaveResized(cropped, size2000Temp, 2000);
                }

                File.Move(cropTemp, Path.Combine(itemFolder, $"{idx}-crop.png"), overwrite: true);
                File.Move(size300Temp, Path.Combine(itemFolder, $"{idx}-300.png"), overwrite: true);
                File.Move(size1200Temp, Path.Combine(itemFolder, $"{idx}-1200.png"), overwrite: true);
                File.Move(size2000Temp, Path.Combine(itemFolder, $"{idx}-2000.png"), overwrite: true);

                entity.Has300 = true;
                entity.Has1200 = true;
                entity.Has2000 = true;
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
            var itemFolder = Path.Combine(_env.WebRootPath, "Images", "items", itemId.ToString());

            // Delete all files for this image (tolerant — ignore missing)
            TryDeleteFile(Path.Combine(itemFolder, $"{idx}-org{ext}"));
            TryDeleteFile(Path.Combine(itemFolder, $"{idx}-crop.png"));
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
                entity.HasNoBg300 = true;
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
                File.Copy(masterPath, Path.Combine(itemFolder, $"{imageIndex}-org{orgExt}"), overwrite: true);

                // Generate sizes from the master: 300 always; 1200/2000 only when the master is
                // natively big enough -- no upscaling above native resolution.
                bool has300 = false, has1200 = false, has2000 = false;
                try
                {
                    using var image = Image.Load(masterPath);
                    SaveResized(image, Path.Combine(itemFolder, $"{imageIndex}-300.png"), 300);
                    has300 = true;
                    if (masterMax >= 1200)
                    {
                        SaveResized(image, Path.Combine(itemFolder, $"{imageIndex}-1200.png"), 1200);
                        has1200 = true;
                    }
                    if (masterMax >= 2000)
                    {
                        SaveResized(image, Path.Combine(itemFolder, $"{imageIndex}-2000.png"), 2000);
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
                    File.Copy(file900.filePath, Path.Combine(itemFolder, $"{imageIndex}-900{srcExt}"), overwrite: true);
                }

                // No 300 produced (resize failed) -> clean up + skip the DB row.
                if (!has300)
                {
                    TryDeleteFile(Path.Combine(itemFolder, $"{imageIndex}-org{orgExt}"));
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

        /// <summary>
        /// File-based backfill: scans item folders on disk and sets Has* flags
        /// based on actual file existence. No inference.
        /// </summary>
        public MigrationResult BackfillVersionFlags()
        {
            var result = new MigrationResult();
            var itemsRoot = Path.Combine(_env.WebRootPath, "Images", "items");

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

                bool h300 = File.Exists(Path.Combine(itemFolder, $"{idx}-300.png"));
                bool h1200 = File.Exists(Path.Combine(itemFolder, $"{idx}-1200.png"));
                bool h2000 = File.Exists(Path.Combine(itemFolder, $"{idx}-2000.png"));
                bool hNb300 = File.Exists(Path.Combine(itemFolder, $"{idx}-300-nobg.png"));
                bool hNb1200 = File.Exists(Path.Combine(itemFolder, $"{idx}-1200-nobg.png"));

                bool changed = false;
                if (entity.Has300 != h300) { entity.Has300 = h300; changed = true; }
                if (entity.Has1200 != h1200) { entity.Has1200 = h1200; changed = true; }
                if (entity.Has2000 != h2000) { entity.Has2000 = h2000; changed = true; }
                if (entity.HasNoBg300 != hNb300) { entity.HasNoBg300 = hNb300; changed = true; }
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
