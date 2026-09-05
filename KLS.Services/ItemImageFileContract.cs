using Microsoft.AspNetCore.Hosting;

namespace KLS.Services
{
    public static class ItemImageFileContract
    {
        public const string ItemImageRootSettingKey = "ITEM_IMAGE_ROOT";
        public const string DefaultItemImageRoot = "~/Images/items";
        public const string ItemImageUrlBase = "/Images/items";
        public const int ThumbnailSize = 300;
        public const int WebSize = 900;
        public const int HighResolutionSize = 1600;
        public const int MarketplaceSize = 2200;
        public const int LegacyWebSize = 1200;
        public const int LegacyLargeSize = 2000;

        public static readonly int[] ActiveWithBackgroundSizes = new[] { ThumbnailSize, WebSize, HighResolutionSize, MarketplaceSize };
        public static readonly int[] LegacyWithBackgroundSizes = new[] { LegacyWebSize, LegacyLargeSize };
        public static readonly int[] ActiveNoBackgroundSizes = new[] { ThumbnailSize, WebSize };
        public static readonly int[] LegacyNoBackgroundSizes = new[] { LegacyWebSize };
        public static readonly string[] NormalDisplayExtensions = new[] { ".webp", ".jpg", ".jpeg", ".png" };
        public static readonly string[] NoBackgroundDisplayExtensions = new[] { ".webp", ".png" };

        public static string ResolveItemImageRoot(IWebHostEnvironment env, string? configuredRoot)
        {
            var root = string.IsNullOrWhiteSpace(configuredRoot)
                ? DefaultItemImageRoot
                : configuredRoot.Trim();

            if (root.StartsWith("~/", StringComparison.Ordinal) || root.StartsWith("~\\", StringComparison.Ordinal))
            {
                var relativePart = root[2..]
                    .Replace('/', Path.DirectorySeparatorChar)
                    .Replace('\\', Path.DirectorySeparatorChar);

                return Path.GetFullPath(Path.Combine(env.WebRootPath, relativePart));
            }

            if (Path.IsPathRooted(root))
                throw new InvalidOperationException($"{ItemImageRootSettingKey} must use a portable ~/Images/items value for this plan.");

            throw new InvalidOperationException($"{ItemImageRootSettingKey} must be blank or start with ~/.");
        }

        public static string GetItemFolderPath(string itemImageRoot, int itemId)
        {
            return Path.Combine(itemImageRoot, itemId.ToString());
        }

        public static string GetItemFolderUrl(string baseUrl, int itemId)
        {
            return $"{baseUrl}{ItemImageUrlBase}/{itemId}";
        }

        public static string GetProcessedFileName(int imageIndex, int size)
        {
            return $"{imageIndex}-{size}.png";
        }

        public static string GetProcessedFileName(int imageIndex, int size, string extension)
        {
            return $"{imageIndex}-{size}{NormalizeDisplayExtension(extension, NormalDisplayExtensions)}";
        }

        public static string GetNoBackgroundFileName(int imageIndex, int size)
        {
            return $"{imageIndex}-{size}-nobg.png";
        }

        public static string GetNoBackgroundFileName(int imageIndex, int size, string extension)
        {
            return $"{imageIndex}-{size}-nobg{NormalizeDisplayExtension(extension, NoBackgroundDisplayExtensions)}";
        }

        public static IEnumerable<string> GetProcessedDisplayFileNames(int imageIndex, int size)
        {
            foreach (var extension in NormalDisplayExtensions)
                yield return GetProcessedFileName(imageIndex, size, extension);
        }

        public static IEnumerable<string> GetNoBackgroundDisplayFileNames(int imageIndex, int size)
        {
            foreach (var extension in NoBackgroundDisplayExtensions)
                yield return GetNoBackgroundFileName(imageIndex, size, extension);
        }

        public static IEnumerable<string> GetOptimizedDisplaySidecarFileNames(int imageIndex)
        {
            foreach (var fileName in GetOptimizedProcessedDisplaySidecarFileNames(imageIndex))
                yield return fileName;

            foreach (var fileName in GetOptimizedNoBackgroundDisplaySidecarFileNames(imageIndex))
                yield return fileName;
        }

        public static IEnumerable<string> GetOptimizedProcessedDisplaySidecarFileNames(int imageIndex)
        {
            foreach (var size in ActiveWithBackgroundSizes.Concat(LegacyWithBackgroundSizes).Distinct())
            {
                foreach (var extension in NormalDisplayExtensions.Where(e => e != ".png"))
                    yield return GetProcessedFileName(imageIndex, size, extension);
            }
        }

        public static IEnumerable<string> GetOptimizedNoBackgroundDisplaySidecarFileNames(int imageIndex)
        {
            foreach (var size in ActiveNoBackgroundSizes.Concat(LegacyNoBackgroundSizes).Distinct())
            {
                foreach (var extension in NoBackgroundDisplayExtensions.Where(e => e != ".png"))
                    yield return GetNoBackgroundFileName(imageIndex, size, extension);
            }
        }

        public static string GetTempProcessedFileName(int imageIndex, int size)
        {
            return $"{imageIndex}-{size}-temp.png";
        }

        public static string GetOriginalFileName(int imageIndex, string originalExtension)
        {
            return $"{imageIndex}-org{originalExtension}";
        }

        public static string GetCropFileName(int imageIndex)
        {
            return $"{imageIndex}-crop.png";
        }

        public static string GetTempPythonFileName(int imageIndex)
        {
            return $"{imageIndex}-temp-python.png";
        }

        public static string GetTempApiFileName(int imageIndex)
        {
            return $"{imageIndex}-temp-api.png";
        }

        public static string GetTempCropFileName(int imageIndex)
        {
            return $"{imageIndex}-crop-temp.png";
        }

        public static string GetRawImportedReferenceFileName(int imageIndex, string extension)
        {
            return $"{imageIndex}-900{extension}";
        }

        public static IEnumerable<string> GetTempFileNames(int imageIndex)
        {
            yield return GetTempPythonFileName(imageIndex);
            yield return GetTempApiFileName(imageIndex);
            yield return GetTempCropFileName(imageIndex);

            foreach (var size in ActiveWithBackgroundSizes.Concat(LegacyWithBackgroundSizes))
                yield return GetTempProcessedFileName(imageIndex, size);
        }

        public static IEnumerable<string> GetRequiredFileNames(
            int imageIndex,
            string? originalExtension,
            ItemImageFileFlags flags)
        {
            if (flags.Has300) yield return GetProcessedFileName(imageIndex, ThumbnailSize);
            if (flags.Has900) yield return GetProcessedFileName(imageIndex, WebSize);
            if (flags.Has1600) yield return GetProcessedFileName(imageIndex, HighResolutionSize);
            if (flags.Has2200) yield return GetProcessedFileName(imageIndex, MarketplaceSize);
            if (flags.Has1200) yield return GetProcessedFileName(imageIndex, LegacyWebSize);
            if (flags.Has2000) yield return GetProcessedFileName(imageIndex, LegacyLargeSize);
            if (flags.HasNoBg300) yield return GetNoBackgroundFileName(imageIndex, ThumbnailSize);
            if (flags.HasNoBg900) yield return GetNoBackgroundFileName(imageIndex, WebSize);
            if (flags.HasNoBg1200) yield return GetNoBackgroundFileName(imageIndex, LegacyWebSize);

            if (!string.IsNullOrWhiteSpace(originalExtension))
                yield return GetOriginalFileName(imageIndex, originalExtension);
        }

        public static bool CanGenerateSize(int effectiveSourceSize, int targetSize)
        {
            return effectiveSourceSize >= targetSize;
        }

        private static string NormalizeDisplayExtension(string extension, IReadOnlyCollection<string> allowedExtensions)
        {
            if (string.IsNullOrWhiteSpace(extension))
                throw new ArgumentException("Display extension is required.", nameof(extension));

            var normalized = extension.StartsWith(".", StringComparison.Ordinal)
                ? extension.ToLowerInvariant()
                : $".{extension.ToLowerInvariant()}";

            if (!allowedExtensions.Contains(normalized))
                throw new ArgumentException($"Unsupported display extension: {extension}", nameof(extension));

            return normalized;
        }
    }

    public readonly record struct ItemImageFileFlags(
        bool Has300,
        bool Has900,
        bool Has1200,
        bool Has1600,
        bool Has2000,
        bool Has2200,
        bool HasNoBg300,
        bool HasNoBg900,
        bool HasNoBg1200);
}
