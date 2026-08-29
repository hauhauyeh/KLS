using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Options;
using Omu.ValueInjecter;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats.Png;
using SixLabors.ImageSharp.Processing;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class ItemCategoryService : BaseService, IItemCategoryService
    {
        private const string HiddenWebCategoryName = "Raw Material";
        private const int CategoryImageIndex = 1;
        private readonly List<ItemCategory> _FlatCategory = new();
        private readonly IWebHostEnvironment hostingEnvironment;
        private readonly IHttpContextAccessor _httpContextAccessor;
        private readonly AppSettings _appSettings;

        private static readonly HashSet<string> AllowedExtensions = new(StringComparer.OrdinalIgnoreCase)
        {
            ".jpg", ".jpeg", ".png", ".webp"
        };

        public ItemCategoryService(
            IUnitOfWork uow,
            IWebHostEnvironment HostingEnvironment,
            IHttpContextAccessor httpContextAccessor,
            IOptions<AppSettings> appSettings) : base(uow)
        {
            hostingEnvironment = HostingEnvironment;
            _httpContextAccessor = httpContextAccessor;
            _appSettings = appSettings.Value;
        }

        public IQueryable<ItemCategory> GetAllCategory()
        {
            return Uow.ItemCategories.GetAll().OrderBy(c => c.SortOrder).ThenBy(c => c.CategoryName);
        }

        public IEnumerable<ItemCategory> GetTree()
        {
            var qry = Uow.ItemCategories.GetAll();

            var category = qry.OrderBy(c => c.SortOrder).ThenBy(c => c.CategoryName).ToList();

            var itemCounts = Uow.Items.Find(i => !i.Inactive && !i.IsDeleted)
                .Where(i => i.CategoryId != null)
                .GroupBy(i => i.CategoryId!.Value)
                .Select(g => new { CategoryId = g.Key, Count = g.Count() })
                .ToDictionary(x => x.CategoryId, x => x.Count);

            return BuildTree(category, null, itemCounts);
        }

        public ItemCategory GetById(int id)
        {
            var category = Uow.ItemCategories.GetById(id);
            if (category != null) ApplyCategoryImageUrls(category);

            return category;
        }

        private IEnumerable<ItemCategory> BuildTree(IEnumerable<ItemCategory> itemCategories, int? parentId, Dictionary<int, int> itemCounts)
        {
            return itemCategories
                .Where(x => x.ParentId == parentId)
                .Select(x =>
                {
                    var item = new ItemCategory();
                    item.InjectFrom(x); // Copies all matching properties
                    item.ItemCount = itemCounts.GetValueOrDefault(x.CategoryId);
                    ApplyCategoryImageUrls(item);

                    // Build child categories
                    item.ChildCategories = BuildTree(itemCategories, x.CategoryId, itemCounts).ToList();

                    return item;
                });
        }

        public IEnumerable<ItemCategoryTree> GetWebTree()
        {
            var allCategories = Uow.ItemCategories.GetAll().ToList();
            var hiddenCategoryIds = GetHiddenWebCategoryIds(allCategories);

            var categories = allCategories
                .Where(c => !c.Inactive)
                .Where(c => !hiddenCategoryIds.Contains(c.CategoryId))
                .OrderBy(c => c.SortOrder).ThenBy(c => c.CategoryName)
                .ToList();

            var itemCountQry = Uow.Items.Find(c => !c.Inactive)
                .Where(i => i.CategoryId != null)
                .Where(i => hiddenCategoryIds.Count == 0 || !hiddenCategoryIds.Contains(i.CategoryId!.Value))
                .GroupBy(i => i.CategoryId!.Value)
                .Select(g => new { CategoryId = g.Key, Count = g.Count() });

            var itemCounts = itemCountQry
                .ToDictionary(x => x.CategoryId, x => x.Count);

            return BuildWebTree(categories, null, itemCounts);
        }

        private static List<int> GetHiddenWebCategoryIds(IEnumerable<ItemCategory> categories)
        {
            var categoryList = categories.ToList();
            var childrenByParent = categoryList
                .Where(c => c.ParentId.HasValue)
                .GroupBy(c => c.ParentId!.Value)
                .ToDictionary(g => g.Key, g => g.Select(c => c.CategoryId).ToList());

            var hiddenIds = new HashSet<int>();
            var stack = new Stack<int>(
                categoryList
                    .Where(c => string.Equals(c.CategoryName?.Trim(), HiddenWebCategoryName, StringComparison.OrdinalIgnoreCase))
                    .Select(c => c.CategoryId));

            while (stack.Count > 0)
            {
                var categoryId = stack.Pop();
                if (!hiddenIds.Add(categoryId)) continue;

                if (!childrenByParent.TryGetValue(categoryId, out var childIds)) continue;

                foreach (var childId in childIds)
                    stack.Push(childId);
            }

            return hiddenIds.ToList();
        }

        private IEnumerable<ItemCategoryTree> BuildWebTree(IEnumerable<ItemCategory> itemCategories, int? parentId, Dictionary<int, int> itemCounts)
        {
            return itemCategories
                .Where(x => x.ParentId == parentId)
                .Select(x =>
                {
                    var children = BuildWebTree(itemCategories, x.CategoryId, itemCounts).ToList();

                    return new ItemCategoryTree
                    {
                        CategoryId = x.CategoryId,
                        ParentId = x.ParentId,
                        CategoryName = x.CategoryName,
                        DisplayName = x.DisplayName,
                        ImageUrl = x.ImageUrl,
                        IsImageProcessed = x.IsImageProcessed,
                        IsImageProcessing = x.IsImageProcessing,
                        ThumbnailUrl = GetCategoryImageUrl(x, "300"),
                        WebImageUrl = GetCategoryImageUrl(x, "1200"),
                        NoBgThumbnailUrl = GetCategoryImageUrl(x, "300-nobg"),
                        NoBgWebImageUrl = GetCategoryImageUrl(x, "1200-nobg"),
                        OriginalUrl = GetOriginalCategoryImageUrl(x),
                        ItemCount = itemCounts.GetValueOrDefault(x.CategoryId),
                        ChildCategories = children.Count > 0 ? children : null
                    };
                });
        }

        public bool NameExists(ItemCategory itemCategory)
        {
            return Uow.ItemCategories.Exists(c => c.CategoryName == itemCategory.CategoryName && c.CategoryId != itemCategory.CategoryId);
        }

        public ItemCategory Create(ItemCategory itemCategory)
        {
            itemCategory.Slug = SlugHelper.GenerateSlug(itemCategory.DisplayName);

            Uow.ItemCategories.Add(itemCategory);
            Uow.Commit();

            return itemCategory;
        }

        public ItemCategory Update(ItemCategory itemCategory)
        {
            var existing = GetById(itemCategory.CategoryId);

            if (existing != null)
            {
                existing.ParentId = itemCategory.ParentId;
                existing.CategoryName = itemCategory.CategoryName;
                existing.DisplayName = itemCategory.DisplayName;
                existing.ForeignName = itemCategory.ForeignName;
                existing.InvoiceName = itemCategory.InvoiceName;
                existing.Description = itemCategory.Description;
                existing.Slug = itemCategory.Slug;
                //existing.ImageUrl = itemCategory.ImageUrl;
                existing.Inactive = itemCategory.Inactive;
                existing.SortOrder = itemCategory.SortOrder;
                existing.Slug = SlugHelper.GenerateSlug(itemCategory.DisplayName);
                existing.UpdatedAt = DateTime.UtcNow;

                Uow.ItemCategories.Update(existing);
                Uow.Commit();
            }

            return existing;
        }

        public void Delete(int categoryId)
        {
            Uow.ItemCategories.RemoveById(categoryId);
            Uow.Commit();
        }

        public ItemCategory UploadImage(int categoryId, IFormFile file, HttpRequest request)
        {
            var category = GetById(categoryId);
            if (category == null)
                throw new KeyNotFoundException("Category not found.");

            if (file == null || file.Length == 0)
                throw new ArgumentException("Please upload an image file.");

            SaveCategoryImageVersions(category, file, request);
            category.UpdatedAt = DateTime.UtcNow;
            ApplyCategoryImageUrls(category);

            Uow.ItemCategories.Update(category);
            Uow.Commit();

            return category;
        }

        public void ReprocessImageOriginal(int categoryId)
        {
            AcquireCategoryImageProcessingLock(categoryId);

            try
            {
                var category = GetRequiredCategory(categoryId);
                if (string.IsNullOrWhiteSpace(category.OriginalImageExtension))
                    throw new Exception("Original category image extension is missing.");

                var folder = GetCategoryFolder(categoryId);
                var idx = CategoryImageIndex;
                var orgPath = Path.Combine(folder, $"{idx}-org{category.OriginalImageExtension}");
                if (!File.Exists(orgPath))
                    throw new FileNotFoundException($"Original category image not found: {idx}-org{category.OriginalImageExtension}");

                var size300Temp = Path.Combine(folder, $"{idx}-300-temp.png");
                var size1200Temp = Path.Combine(folder, $"{idx}-1200-temp.png");

                CleanupCategoryTempFiles(folder);

                using (var image = Image.Load(orgPath))
                {
                    SaveResized(image, size300Temp, 300);
                    SaveResized(image, size1200Temp, 1200);
                }

                File.Move(size300Temp, Path.Combine(folder, $"{idx}-300.png"), overwrite: true);
                File.Move(size1200Temp, Path.Combine(folder, $"{idx}-1200.png"), overwrite: true);

                category.HasImage300 = true;
                category.HasImage1200 = true;
                category.ImageUrl = GetCategoryImageUrl(category, "1200") ?? category.ImageUrl;
                category.UpdatedAt = DateTime.UtcNow;
                Uow.ItemCategories.Update(category);
                Uow.Commit();
            }
            finally
            {
                CleanupCategoryTempFiles(GetCategoryFolderPath(categoryId));
                ReleaseCategoryImageProcessingLock(categoryId);
            }
        }

        public async Task<CategoryImageProcessResult> ProcessImageBgLocal(int categoryId)
        {
            AcquireCategoryImageProcessingLock(categoryId);

            try
            {
                var category = GetRequiredCategory(categoryId);
                var folder = GetCategoryFolder(categoryId);
                var orgPath = GetOriginalCategoryImagePath(category, folder);
                var tempOutput = Path.Combine(folder, $"{CategoryImageIndex}-temp-python.png");

                await RunPythonAsync(
                    GetScriptPath("remove_bg_local.py"),
                    new[] { orgPath, tempOutput }
                );

                if (!File.Exists(tempOutput))
                    throw new Exception("Python background removal did not produce an output file.");

                return new CategoryImageProcessResult
                {
                    CategoryId = categoryId,
                    OriginalUrl = GetOriginalCategoryImageUrl(category),
                    PythonProcessedUrl = GetCategoryImageUrl(category, "temp-python")
                };
            }
            catch
            {
                TryDeleteFile(Path.Combine(GetCategoryFolderPath(categoryId), $"{CategoryImageIndex}-temp-python.png"));
                throw;
            }
            finally
            {
                ReleaseCategoryImageProcessingLock(categoryId);
            }
        }

        public async Task<CategoryImageProcessResult> ProcessImageBgApi(int categoryId)
        {
            AcquireCategoryImageProcessingLock(categoryId);

            try
            {
                var category = GetRequiredCategory(categoryId);
                var folder = GetCategoryFolder(categoryId);
                var orgPath = GetOriginalCategoryImagePath(category, folder);
                var tempOutput = Path.Combine(folder, $"{CategoryImageIndex}-temp-api.png");

                var apiKey = _appSettings.RemoveBgApiKey
                    ?? throw new Exception("RemoveBgApiKey not configured in appsettings.");

                await RunPythonAsync(
                    GetScriptPath("remove_bg_api.py"),
                    new[] { orgPath, tempOutput, apiKey }
                );

                if (!File.Exists(tempOutput))
                    throw new Exception("API background removal did not produce an output file.");

                return new CategoryImageProcessResult
                {
                    CategoryId = categoryId,
                    OriginalUrl = GetOriginalCategoryImageUrl(category),
                    ApiProcessedUrl = GetCategoryImageUrl(category, "temp-api")
                };
            }
            catch
            {
                TryDeleteFile(Path.Combine(GetCategoryFolderPath(categoryId), $"{CategoryImageIndex}-temp-api.png"));
                throw;
            }
            finally
            {
                ReleaseCategoryImageProcessingLock(categoryId);
            }
        }

        public async Task FinalizeImage(CategoryImageFinalizeReq req)
        {
            AcquireCategoryImageProcessingLock(req.CategoryId);

            try
            {
                var category = GetRequiredCategory(req.CategoryId);

                if (req.SelectedVersion == 1)
                {
                    category.IsImageProcessed = false;
                    category.HasNoBg300 = false;
                    category.HasNoBg1200 = false;
                    category.UpdatedAt = DateTime.UtcNow;
                    Uow.ItemCategories.Update(category);
                    Uow.Commit();
                    return;
                }

                var folder = GetCategoryFolder(req.CategoryId);
                var source = req.SelectedVersion switch
                {
                    2 => Path.Combine(folder, $"{CategoryImageIndex}-temp-python.png"),
                    3 => Path.Combine(folder, $"{CategoryImageIndex}-temp-api.png"),
                    _ => throw new Exception($"Invalid SelectedVersion: {req.SelectedVersion}")
                };

                if (!File.Exists(source))
                    throw new FileNotFoundException("Selected background-removed source was not found.");

                await RunPythonAsync(
                    GetScriptPath("create_sizes.py"),
                    new[] { source, folder, CategoryImageIndex.ToString() }
                );

                var nobg300 = Path.Combine(folder, $"{CategoryImageIndex}-300-nobg.png");
                var nobg1200 = Path.Combine(folder, $"{CategoryImageIndex}-1200-nobg.png");

                if (!File.Exists(nobg300) || !File.Exists(nobg1200))
                    throw new Exception("create_sizes.py did not produce expected category no-bg output files.");

                category.IsImageProcessed = true;
                category.HasNoBg300 = true;
                category.HasNoBg1200 = true;
                category.UpdatedAt = DateTime.UtcNow;
                Uow.ItemCategories.Update(category);
                Uow.Commit();
            }
            finally
            {
                CleanupCategoryTempFiles(GetCategoryFolderPath(req.CategoryId));
                ReleaseCategoryImageProcessingLock(req.CategoryId);
            }
        }

        private void SaveCategoryImageVersions(ItemCategory category, IFormFile file, HttpRequest request)
        {
            ValidateImageFile(file);

            var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
            var folder = GetCategoryFolder(category.CategoryId);
            var idx = CategoryImageIndex;
            var tempFolder = Path.Combine(folder, $".upload-{Guid.NewGuid():N}");
            Directory.CreateDirectory(tempFolder);

            try
            {
                var tempOrgPath = Path.Combine(tempFolder, $"{idx}-org{extension}");
                var temp300Path = Path.Combine(tempFolder, $"{idx}-300.png");
                var temp1200Path = Path.Combine(tempFolder, $"{idx}-1200.png");

                using (var fileStream = new FileStream(tempOrgPath, FileMode.Create))
                {
                    file.CopyTo(fileStream);
                }

                using (var image = Image.Load(tempOrgPath))
                {
                    SaveResized(image, temp300Path, 300);
                    SaveResized(image, temp1200Path, 1200);
                }

                DeleteCategoryImageFiles(category);
                Directory.CreateDirectory(folder);

                var orgPath = Path.Combine(folder, $"{idx}-org{extension}");
                var image300Path = Path.Combine(folder, $"{idx}-300.png");
                var image1200Path = Path.Combine(folder, $"{idx}-1200.png");

                File.Move(tempOrgPath, orgPath, overwrite: true);
                File.Move(temp300Path, image300Path, overwrite: true);
                File.Move(temp1200Path, image1200Path, overwrite: true);

                category.OriginalImageExtension = extension;
                category.IsImageProcessed = false;
                category.IsImageProcessing = false;
                category.HasImage300 = File.Exists(image300Path);
                category.HasImage1200 = File.Exists(image1200Path);
                category.HasNoBg300 = false;
                category.HasNoBg1200 = false;
                category.ImageUrl = GetCategoryImageUrl(category, "1200", request) ?? GetCategoryImageUrl(category, "300", request);
            }
            finally
            {
                if (Directory.Exists(tempFolder))
                {
                    try { Directory.Delete(tempFolder, recursive: true); } catch { }
                }
            }
        }

        private static void ValidateImageFile(IFormFile file)
        {
            var extension = Path.GetExtension(file.FileName).ToLowerInvariant();

            if (!AllowedExtensions.Contains(extension) || !file.ContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
                throw new ArgumentException("Please upload a JPG, PNG, or WEBP image file.");
        }

        public void DeleteImage(int catId)
        {
            var cat = GetById(catId);

            if (cat != null)
            {
                DeleteCategoryImageFiles(cat);

                cat.ImageUrl = null;
                ClearCategoryImageMetadata(cat);
                Uow.ItemCategories.Update(cat);
                Uow.Commit();
            }
        }

        public void ReorderNode(ItemCategoryReorderReq dto)
        {
            var cat = Uow.ItemCategories.GetById(dto.Id);
            if (cat == null) throw new Exception("Category not found");

            var siblings = Uow.ItemCategories.Find(c => c.ParentId == cat.ParentId)
                .OrderBy(c => c.SortOrder).ThenBy(c => c.CategoryName).ToList();

            // Normalize SortOrders
            for (int i = 0; i < siblings.Count; i++)
                siblings[i].SortOrder = (i + 1) * 10;

            var currentIndex = siblings.FindIndex(c => c.CategoryId == dto.Id);
            if (currentIndex == -1) throw new Exception("Category not found in siblings");

            int targetIndex = dto.Direction == "Up" ? currentIndex - 1 : currentIndex + 1;

            if (targetIndex >= 0 && targetIndex < siblings.Count)
            {
                // Swap SortOrder values
                int tempSort = siblings[currentIndex].SortOrder;
                siblings[currentIndex].SortOrder = siblings[targetIndex].SortOrder;
                siblings[targetIndex].SortOrder = tempSort;
            }

            foreach (var s in siblings)
                Uow.ItemCategories.Update(s);

            Uow.Commit();
        }

        private void DeleteCategoryImageFiles(ItemCategory itemCategory)
        {
            var categoryFolder = GetCategoryFolderPath(itemCategory.CategoryId);
            var ext = itemCategory.OriginalImageExtension;

            if (!string.IsNullOrWhiteSpace(ext))
            {
                TryDeleteFile(Path.Combine(categoryFolder, $"{CategoryImageIndex}-org{ext}"));
            }

            TryDeleteFile(Path.Combine(categoryFolder, $"{CategoryImageIndex}-300.png"));
            TryDeleteFile(Path.Combine(categoryFolder, $"{CategoryImageIndex}-1200.png"));
            TryDeleteFile(Path.Combine(categoryFolder, $"{CategoryImageIndex}-300-nobg.png"));
            TryDeleteFile(Path.Combine(categoryFolder, $"{CategoryImageIndex}-1200-nobg.png"));
            CleanupCategoryTempFiles(categoryFolder);

            if (!string.IsNullOrEmpty(itemCategory.ImageUrl))
            {
                var fileName = Path.GetFileName(itemCategory.ImageUrl.Split('?')[0]);
                var legacyPath = Path.Combine(hostingEnvironment.WebRootPath, "Images", "category", fileName);
                TryDeleteFile(legacyPath);
            }

            if (Directory.Exists(categoryFolder) && !Directory.EnumerateFileSystemEntries(categoryFolder).Any())
            {
                try { Directory.Delete(categoryFolder); } catch { }
            }
        }

        private ItemCategory GetRequiredCategory(int categoryId)
        {
            var category = Uow.ItemCategories.GetById(categoryId);
            if (category == null) throw new KeyNotFoundException("Category not found.");
            return category;
        }

        private string GetCategoryFolder(int categoryId)
        {
            var folder = GetCategoryFolderPath(categoryId);
            Directory.CreateDirectory(folder);
            return folder;
        }

        private string GetCategoryFolderPath(int categoryId)
        {
            return Path.Combine(hostingEnvironment.WebRootPath, "Images", "category", categoryId.ToString());
        }

        private string GetScriptPath(string scriptName)
        {
            return Path.Combine(hostingEnvironment.ContentRootPath, "Python", scriptName);
        }

        private string GetBaseUrl()
        {
            var request = _httpContextAccessor.HttpContext?.Request;
            if (request == null) return "";
            return $"{request.Scheme}://{request.Host}";
        }

        private static void SaveResized(Image source, string outputPath, int targetSize)
        {
            using var rgba = source.CloneAs<SixLabors.ImageSharp.PixelFormats.Rgba32>();
            rgba.Mutate(x => x.Resize(new ResizeOptions
            {
                Mode = ResizeMode.Pad,
                Size = new SixLabors.ImageSharp.Size(targetSize, targetSize),
                PadColor = SixLabors.ImageSharp.Color.Transparent
            }));
            rgba.Save(outputPath, new PngEncoder());
        }

        private void ApplyCategoryImageUrls(ItemCategory category)
        {
            category.ThumbnailUrl = GetCategoryImageUrl(category, "300");
            category.WebImageUrl = GetCategoryImageUrl(category, "1200");
            category.NoBgThumbnailUrl = GetCategoryImageUrl(category, "300-nobg");
            category.NoBgWebImageUrl = GetCategoryImageUrl(category, "1200-nobg");
            category.OriginalUrl = GetOriginalCategoryImageUrl(category);
        }

        private string? GetCategoryImageUrl(ItemCategory category, string suffix, HttpRequest? request = null)
        {
            var hasFile = suffix switch
            {
                "300" => category.HasImage300,
                "1200" => category.HasImage1200,
                "300-nobg" => category.HasNoBg300,
                "1200-nobg" => category.HasNoBg1200,
                "temp-python" => true,
                "temp-api" => true,
                _ => false
            };

            if (!hasFile) return null;

            var baseUrl = request == null
                ? GetBaseUrl()
                : $"{request.Scheme}://{request.Host}{request.PathBase}";

            return $"{baseUrl}/Images/category/{category.CategoryId}/{CategoryImageIndex}-{suffix}.png";
        }

        private string? GetOriginalCategoryImageUrl(ItemCategory category)
        {
            if (string.IsNullOrWhiteSpace(category.OriginalImageExtension)) return null;
            return $"{GetBaseUrl()}/Images/category/{category.CategoryId}/{CategoryImageIndex}-org{category.OriginalImageExtension}";
        }

        private string GetOriginalCategoryImagePath(ItemCategory category, string folder)
        {
            var ext = category.OriginalImageExtension ?? ".png";
            var orgPath = Path.Combine(folder, $"{CategoryImageIndex}-org{ext}");
            if (!File.Exists(orgPath))
                throw new FileNotFoundException($"Original category image not found: {CategoryImageIndex}-org{ext}");

            return orgPath;
        }

        private void ClearCategoryImageMetadata(ItemCategory category)
        {
            category.OriginalImageExtension = null;
            category.IsImageProcessed = false;
            category.IsImageProcessing = false;
            category.HasImage300 = false;
            category.HasImage1200 = false;
            category.HasNoBg300 = false;
            category.HasNoBg1200 = false;
            category.ThumbnailUrl = null;
            category.WebImageUrl = null;
            category.NoBgThumbnailUrl = null;
            category.NoBgWebImageUrl = null;
            category.OriginalUrl = null;
        }

        private static void CopyCategoryImageState(ItemCategory source, ItemCategory target)
        {
            target.ImageUrl = source.ImageUrl;
            target.OriginalImageExtension = source.OriginalImageExtension;
            target.IsImageProcessed = source.IsImageProcessed;
            target.IsImageProcessing = source.IsImageProcessing;
            target.HasImage300 = source.HasImage300;
            target.HasImage1200 = source.HasImage1200;
            target.HasNoBg300 = source.HasNoBg300;
            target.HasNoBg1200 = source.HasNoBg1200;
            target.ThumbnailUrl = source.ThumbnailUrl;
            target.WebImageUrl = source.WebImageUrl;
            target.NoBgThumbnailUrl = source.NoBgThumbnailUrl;
            target.NoBgWebImageUrl = source.NoBgWebImageUrl;
            target.OriginalUrl = source.OriginalUrl;
        }

        private void AcquireCategoryImageProcessingLock(int categoryId)
        {
            var category = GetRequiredCategory(categoryId);
            if (category.IsImageProcessing) throw new Exception("Category image is already being processed.");

            category.IsImageProcessing = true;
            Uow.ItemCategories.Update(category);
            Uow.Commit();
        }

        private void ReleaseCategoryImageProcessingLock(int categoryId)
        {
            try
            {
                var category = Uow.ItemCategories.GetById(categoryId);
                if (category != null)
                {
                    category.IsImageProcessing = false;
                    Uow.ItemCategories.Update(category);
                    Uow.Commit();
                }
            }
            catch { /* best effort */ }
        }

        private static void TryDeleteFile(string path)
        {
            try { if (File.Exists(path)) File.Delete(path); } catch { }
        }

        private static void CleanupCategoryTempFiles(string folder)
        {
            TryDeleteFile(Path.Combine(folder, $"{CategoryImageIndex}-temp-python.png"));
            TryDeleteFile(Path.Combine(folder, $"{CategoryImageIndex}-temp-api.png"));
            TryDeleteFile(Path.Combine(folder, $"{CategoryImageIndex}-300-temp.png"));
            TryDeleteFile(Path.Combine(folder, $"{CategoryImageIndex}-1200-temp.png"));
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

            var appData = Path.Combine(hostingEnvironment.ContentRootPath, "App_Data");
            Directory.CreateDirectory(appData);
            var pyCache = Path.Combine(appData, "python_cache");
            Directory.CreateDirectory(pyCache);

            psi.Environment["TEMP"] = pyCache;
            psi.Environment["TMP"] = pyCache;
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
    }
}
