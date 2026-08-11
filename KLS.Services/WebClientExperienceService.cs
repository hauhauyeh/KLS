using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models.WebClientExperience;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

namespace KLS.Services
{
    public class WebClientExperienceService : BaseService, IWebClientExperienceService
    {
        private const int MaxSections = 30;
        private const int MaxSlides = 10;
        private const int MaxCtas = 3;
        private const int MaxTextLength = 500;
        private const int MaxBodyLength = 2000;
        private const int MaxUrlLength = 1000;
        private const int MaxItems = 24;
        private const string TemplateFileName = "web-client-experience.json";
        private const string DefaultTemplateKey = "default";

        private static readonly JsonSerializerOptions ProfileJsonOptions = new()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
            WriteIndented = false
        };

        private static readonly JsonSerializerOptions ReadJsonOptions = new()
        {
            PropertyNameCaseInsensitive = true
        };

        private static readonly HashSet<string> SectionTypes = new(StringComparer.Ordinal)
        {
            "hero",
            "categoryTiles",
            "featuredProducts",
            "productCarousel",
            "promoCarousel",
            "promoBand",
            "serviceCards",
            "storyBlock",
            "recentlyOrdered",
            "bestSellers"
        };

        private static readonly HashSet<string> HomeModes = new(StringComparer.Ordinal)
        {
            "internal",
            "external"
        };

        private static readonly HashSet<string> HomePresets = new(StringComparer.Ordinal)
        {
            "catalog-first",
            "wholesale-utility",
            "retail-utility"
        };

        private static readonly HashSet<string> HomeLayoutPresets = new(StringComparer.Ordinal)
        {
            "catalog-first",
            "brand-hero",
            "promo-storefront",
            "wholesale-utility",
            "retail-utility",
            "quick-order"
        };

        private static readonly HashSet<string> HomeWidths = new(StringComparer.Ordinal)
        {
            "full",
            "contained"
        };

        private static readonly HashSet<string> MediaTypes = new(StringComparer.Ordinal)
        {
            "image",
            "video"
        };

        private static readonly HashSet<string> Sources = new(StringComparer.Ordinal)
        {
            "manual",
            "category",
            "recentlyOrdered",
            "bestSellers"
        };

        private static readonly HashSet<string> CtaStyles = new(StringComparer.Ordinal)
        {
            "primary",
            "secondary",
            "link"
        };

        private static readonly HashSet<string> PortalModes = new(StringComparer.Ordinal)
        {
            "B2B",
            "B2C",
            "any"
        };

        private static readonly Regex HtmlTagRegex = new("<[^>]+>", RegexOptions.Compiled);

        private readonly ISystemSettingService _systemSettingService;
        private readonly IPortalModeService _portalModeService;
        private readonly ICompanyService _companyService;
        private readonly IConfiguration _configuration;
        private readonly IWebHostEnvironment _env;

        public WebClientExperienceService(
            IUnitOfWork uow,
            ISystemSettingService systemSettingService,
            IPortalModeService portalModeService,
            ICompanyService companyService,
            IConfiguration configuration,
            IWebHostEnvironment env) : base(uow)
        {
            _systemSettingService = systemSettingService;
            _portalModeService = portalModeService;
            _companyService = companyService;
            _configuration = configuration;
            _env = env;
        }

        public WebClientHomeContentDto GetHomeContent()
        {
            var json = _systemSettingService.GetByKey<string>(GlobalKey.WEB_CLIENT_EXPERIENCE_JSON);
            var profile = ParseProfile(json);

            return new WebClientHomeContentDto
            {
                Home = MergeHome(GetDefaultHome(), ReadObject<WebClientHomeDto>(profile["Home"])),
                HomeLayout = MergeHomeLayout(WebClientHomeLayoutDto.Default(), ReadObject<WebClientHomeLayoutDto>(GetLayoutObject(profile)?["home"])),
                HasProfile = !string.IsNullOrWhiteSpace(json)
            };
        }

        public WebClientExperienceTemplateListDto GetTemplates()
        {
            var root = GetTemplateRoot();
            var templates = Directory.GetDirectories(root)
                .Select(path => new
                {
                    Path = path,
                    TemplateKey = Path.GetFileName(path)
                })
                .Where(x => !string.IsNullOrWhiteSpace(x.TemplateKey))
                .Where(x => File.Exists(Path.Combine(x.Path, TemplateFileName)))
                .Select(x => new WebClientExperienceTemplateDto
                {
                    TemplateKey = x.TemplateKey!,
                    DisplayName = FormatTemplateName(x.TemplateKey!),
                    IsDefault = string.Equals(x.TemplateKey, DefaultTemplateKey, StringComparison.OrdinalIgnoreCase)
                })
                .OrderBy(x => x.IsDefault ? 0 : 1)
                .ThenBy(x => x.DisplayName, StringComparer.OrdinalIgnoreCase)
                .ToList();

            return new WebClientExperienceTemplateListDto
            {
                Templates = templates,
                HasDefault = templates.Any(x => x.IsDefault)
            };
        }

        public WebClientExperienceTemplateActionDto ResetHomeContentFromDefaultTemplate()
        {
            var json = ReadTemplateJson(DefaultTemplateKey);
            ReplaceProfileJson(json);

            return new WebClientExperienceTemplateActionDto
            {
                TemplateKey = DefaultTemplateKey,
                Message = "Default template loaded.",
                HomeContent = GetHomeContent()
            };
        }

        public WebClientExperienceTemplateActionDto LoadHomeContentFromTemplate(string templateKey)
        {
            var normalizedKey = NormalizeTemplateKey(templateKey, allowDefault: false);
            var json = ReadTemplateJson(normalizedKey);
            ReplaceProfileJson(json);

            return new WebClientExperienceTemplateActionDto
            {
                TemplateKey = normalizedKey,
                Message = $"{FormatTemplateName(normalizedKey)} template loaded.",
                HomeContent = GetHomeContent()
            };
        }

        public WebClientExperienceTemplateActionDto SaveCurrentProfileToTemplate(string templateKey)
        {
            var normalizedKey = NormalizeTemplateKey(templateKey, allowDefault: false);
            var json = _systemSettingService.GetByKey<string>(GlobalKey.WEB_CLIENT_EXPERIENCE_JSON);

            if (string.IsNullOrWhiteSpace(json))
                throw new ArgumentException("WEB_CLIENT_EXPERIENCE_JSON is missing.");

            ValidateProfileJson(json);

            var path = GetTemplateFilePath(normalizedKey, mustExist: false);
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            File.WriteAllText(path, NormalizeJson(json));

            return new WebClientExperienceTemplateActionDto
            {
                TemplateKey = normalizedKey,
                Message = $"{FormatTemplateName(normalizedKey)} template saved."
            };
        }

        public WebClientHomeContentDto UpdateHomeContent(WebClientHomeContentUpdateReq req)
        {
            if (req == null)
                throw new ArgumentException("Home content is required.");

            var home = NormalizeHome(req.Home);
            var homeLayout = NormalizeHomeLayout(req.HomeLayout);
            var currentJson = _systemSettingService.GetByKey<string>(GlobalKey.WEB_CLIENT_EXPERIENCE_JSON);
            var profile = ParseProfile(currentJson);

            profile["Home"] = JsonSerializer.SerializeToNode(home, ProfileJsonOptions);

            var layout = GetOrCreateLayoutObject(profile);
            layout["home"] = JsonSerializer.SerializeToNode(homeLayout, ProfileJsonOptions);

            var nextJson = profile.ToJsonString(ProfileJsonOptions);

            Uow.ExecuteInTransaction(() =>
            {
                if (!string.IsNullOrWhiteSpace(currentJson))
                {
                    _systemSettingService.SetByKey(
                        GlobalKey.WEB_CLIENT_EXPERIENCE_JSON_PREVIOUS,
                        currentJson,
                        "json",
                        "Previous web client experience profile JSON",
                        commit: false);
                }

                _systemSettingService.SetByKey(
                    GlobalKey.WEB_CLIENT_EXPERIENCE_JSON,
                    nextJson,
                    "json",
                    "Web client experience profile JSON",
                    commit: false);

                Uow.Commit();
            });

            return new WebClientHomeContentDto
            {
                Home = home,
                HomeLayout = homeLayout,
                HasProfile = true
            };
        }

        private string ReadTemplateJson(string templateKey)
        {
            var path = GetTemplateFilePath(templateKey, mustExist: true);
            var json = File.ReadAllText(path);
            ValidateProfileJson(json);
            return NormalizeJson(json);
        }

        private void ReplaceProfileJson(string nextJson)
        {
            ValidateProfileJson(nextJson);

            var currentJson = _systemSettingService.GetByKey<string>(GlobalKey.WEB_CLIENT_EXPERIENCE_JSON);

            Uow.ExecuteInTransaction(() =>
            {
                if (!string.IsNullOrWhiteSpace(currentJson))
                {
                    _systemSettingService.SetByKey(
                        GlobalKey.WEB_CLIENT_EXPERIENCE_JSON_PREVIOUS,
                        currentJson,
                        "json",
                        "Previous web client experience profile JSON",
                        commit: false);
                }

                _systemSettingService.SetByKey(
                    GlobalKey.WEB_CLIENT_EXPERIENCE_JSON,
                    nextJson,
                    "json",
                    "Web client experience profile JSON",
                    commit: false);

                Uow.Commit();
            });
        }

        private string GetTemplateFilePath(string templateKey, bool mustExist)
        {
            var normalizedKey = NormalizeTemplateKey(templateKey, allowDefault: true);
            var root = GetTemplateRoot();
            var path = Path.GetFullPath(Path.Combine(root, normalizedKey, TemplateFileName));
            var expectedRoot = Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)
                + Path.DirectorySeparatorChar;

            if (!path.StartsWith(expectedRoot, StringComparison.OrdinalIgnoreCase))
                throw new ArgumentException("Template path is invalid.");

            if (mustExist && !File.Exists(path))
                throw new ArgumentException($"Template '{normalizedKey}' does not exist.");

            return path;
        }

        private string GetTemplateRoot()
        {
            var configured = _configuration["WebClientExperience:TemplateRootPath"];
            var root = string.IsNullOrWhiteSpace(configured)
                ? FindLocalTemplateRoot()
                : configured.Trim();

            if (string.IsNullOrWhiteSpace(root))
                throw new InvalidOperationException("Web client experience template root is not configured.");

            var fullRoot = Path.GetFullPath(root);
            if (!Directory.Exists(fullRoot))
                throw new InvalidOperationException($"Web client experience template root does not exist: {fullRoot}");

            return fullRoot;
        }

        private string? FindLocalTemplateRoot()
        {
            var dir = new DirectoryInfo(_env.ContentRootPath);

            while (dir != null)
            {
                var candidate = Path.Combine(dir.FullName, "KLS-Web-21", "client-configs");
                if (Directory.Exists(candidate))
                    return candidate;

                dir = dir.Parent;
            }

            return null;
        }

        private static string NormalizeTemplateKey(string templateKey, bool allowDefault)
        {
            var key = templateKey?.Trim().ToLowerInvariant();
            if (string.IsNullOrWhiteSpace(key))
                throw new ArgumentException("Template is required.");

            if (!allowDefault && string.Equals(key, DefaultTemplateKey, StringComparison.OrdinalIgnoreCase))
                throw new ArgumentException("Default template must be used through Reset To Default.");

            if (!Regex.IsMatch(key, "^[a-z0-9-]+$", RegexOptions.CultureInvariant))
                throw new ArgumentException("Template name is invalid.");

            return key;
        }

        private static void ValidateProfileJson(string json)
        {
            if (string.IsNullOrWhiteSpace(json))
                throw new ArgumentException("Web client experience profile JSON is required.");

            ParseProfile(json);
        }

        private static string NormalizeJson(string json)
        {
            return ParseProfile(json).ToJsonString(ProfileJsonOptions);
        }

        private static string FormatTemplateName(string templateKey)
        {
            return string.Join(" ", templateKey
                .Split('-', StringSplitOptions.RemoveEmptyEntries)
                .Select(part => part.Length == 0
                    ? part
                    : char.ToUpperInvariant(part[0]) + part[1..]));
        }

        private static JsonObject ParseProfile(string? json)
        {
            if (string.IsNullOrWhiteSpace(json))
                return new JsonObject();

            try
            {
                var node = JsonNode.Parse(json);
                return node as JsonObject
                    ?? throw new ArgumentException("Web client experience profile must be a JSON object.");
            }
            catch (JsonException ex)
            {
                throw new ArgumentException("Web client experience profile JSON is invalid.", ex);
            }
        }

        private static T? ReadObject<T>(JsonNode? node)
        {
            if (node == null)
                return default;

            try
            {
                return node.Deserialize<T>(ReadJsonOptions);
            }
            catch (JsonException ex)
            {
                throw new ArgumentException("Web client experience home profile is invalid.", ex);
            }
        }

        private static JsonObject? GetLayoutObject(JsonObject profile)
        {
            var layoutNode = profile["Layout"];
            if (layoutNode == null)
                return null;

            return layoutNode as JsonObject
                ?? throw new ArgumentException("Web client experience Layout must be a JSON object.");
        }

        private static JsonObject GetOrCreateLayoutObject(JsonObject profile)
        {
            var layout = GetLayoutObject(profile);
            if (layout != null)
                return layout;

            layout = new JsonObject();
            profile["Layout"] = layout;
            return layout;
        }

        private WebClientHomeDto GetDefaultHome()
        {
            var clientKey = _companyService.GetDefault()?.CompanyCode?.Trim().ToUpperInvariant();
            var isABC = clientKey == "ABC";
            var isB2C = _portalModeService.IsB2C();

            return new WebClientHomeDto
            {
                Mode = isABC ? "external" : "internal",
                PostLoginRedirect = isABC ? "/products" : "/products?iswishlist=true",
                Preset = isB2C ? "retail-utility" : "wholesale-utility",
                Sections = new List<WebClientHomeSectionDto>()
            };
        }

        private static WebClientHomeDto MergeHome(WebClientHomeDto defaults, WebClientHomeDto? configured)
        {
            if (configured == null)
                return defaults;

            return new WebClientHomeDto
            {
                Mode = string.IsNullOrWhiteSpace(configured.Mode) ? defaults.Mode : configured.Mode,
                ExternalHomeUrl = string.IsNullOrWhiteSpace(configured.ExternalHomeUrl) ? defaults.ExternalHomeUrl : configured.ExternalHomeUrl,
                PostLoginRedirect = string.IsNullOrWhiteSpace(configured.PostLoginRedirect) ? defaults.PostLoginRedirect : configured.PostLoginRedirect,
                Preset = string.IsNullOrWhiteSpace(configured.Preset) ? defaults.Preset : configured.Preset,
                Sections = configured.Sections ?? defaults.Sections
            };
        }

        private static WebClientHomeLayoutDto MergeHomeLayout(WebClientHomeLayoutDto defaults, WebClientHomeLayoutDto? configured)
        {
            if (configured == null)
                return defaults;

            return new WebClientHomeLayoutDto
            {
                Width = MergeResponsiveString(defaults.Width, configured.Width),
                Preset = MergeResponsiveString(defaults.Preset, configured.Preset),
                ShowServiceStrip = MergeResponsiveBool(defaults.ShowServiceStrip, configured.ShowServiceStrip)
            };
        }

        private static ResponsiveStringValueDto MergeResponsiveString(ResponsiveStringValueDto defaults, ResponsiveStringValueDto? configured)
        {
            if (configured == null)
                return defaults;

            return new ResponsiveStringValueDto
            {
                Desktop = string.IsNullOrWhiteSpace(configured.Desktop) ? defaults.Desktop : configured.Desktop,
                Tablet = string.IsNullOrWhiteSpace(configured.Tablet) ? defaults.Tablet : configured.Tablet,
                Mobile = string.IsNullOrWhiteSpace(configured.Mobile) ? defaults.Mobile : configured.Mobile
            };
        }

        private static ResponsiveBoolValueDto MergeResponsiveBool(ResponsiveBoolValueDto defaults, ResponsiveBoolValueDto? configured)
        {
            if (configured == null)
                return defaults;

            return new ResponsiveBoolValueDto
            {
                Desktop = configured.Desktop,
                Tablet = configured.Tablet ?? defaults.Tablet,
                Mobile = configured.Mobile ?? defaults.Mobile
            };
        }

        private static WebClientHomeDto NormalizeHome(WebClientHomeDto? home)
        {
            home ??= WebClientHomeDto.Default();
            home.Mode = NormalizeRequiredEnum(home.Mode, HomeModes, "Home mode");
            home.Preset = NormalizeRequiredEnum(home.Preset, HomePresets, "Home preset");
            home.ExternalHomeUrl = NormalizeOptionalUrl(home.ExternalHomeUrl, "External home URL", allowExternal: true);
            home.PostLoginRedirect = NormalizeOptionalUrl(home.PostLoginRedirect, "Post-login redirect", allowExternal: false);

            home.Sections ??= new List<WebClientHomeSectionDto>();
            if (home.Sections.Count > MaxSections)
                throw new ArgumentException($"Home sections cannot exceed {MaxSections}.");

            home.Sections = home.Sections.Select(NormalizeSection).ToList();
            return home;
        }

        private static WebClientHomeLayoutDto NormalizeHomeLayout(WebClientHomeLayoutDto? layout)
        {
            layout ??= WebClientHomeLayoutDto.Default();
            layout.Width = NormalizeResponsiveString(layout.Width, HomeWidths, "Home width");
            layout.Preset = NormalizeResponsiveString(layout.Preset, HomeLayoutPresets, "Home layout preset");
            layout.ShowServiceStrip ??= new ResponsiveBoolValueDto { Desktop = false };
            return layout;
        }

        private static WebClientHomeSectionDto NormalizeSection(WebClientHomeSectionDto section)
        {
            if (section == null)
                throw new ArgumentException("Home section is required.");

            section.Type = NormalizeRequiredEnum(section.Type, SectionTypes, "Section type");
            section.Title = NormalizeOptionalText(section.Title, "Section title", MaxTextLength);
            section.Subtitle = NormalizeOptionalText(section.Subtitle, "Section subtitle", MaxTextLength);
            section.Body = NormalizeOptionalText(section.Body, "Section body", MaxBodyLength);
            section.ImageUrl = NormalizeOptionalImageUrl(section.ImageUrl, "Section image URL");
            section.MobileImageUrl = NormalizeOptionalImageUrl(section.MobileImageUrl, "Section mobile image URL");
            section.MediaType = NormalizeOptionalEnum(section.MediaType, MediaTypes, "Section media type");
            section.VideoUrl = NormalizeOptionalUrl(section.VideoUrl, "Section video URL", allowExternal: true);
            section.CtaText = NormalizeOptionalText(section.CtaText, "Section CTA text", MaxTextLength);
            section.CtaLink = NormalizeOptionalUrl(section.CtaLink, "Section CTA link", allowExternal: true);
            section.SecondaryCtaText = NormalizeOptionalText(section.SecondaryCtaText, "Section secondary CTA text", MaxTextLength);
            section.SecondaryCtaLink = NormalizeOptionalUrl(section.SecondaryCtaLink, "Section secondary CTA link", allowExternal: true);
            section.Source = NormalizeOptionalEnum(section.Source, Sources, "Section source");
            section.MaxItems = NormalizeMaxItems(section.MaxItems);
            section.CategoryIds = NormalizePositiveIds(section.CategoryIds, "Category IDs");
            section.ItemIds = NormalizePositiveIds(section.ItemIds, "Item IDs");
            section.Ctas = NormalizeCtas(section.Ctas);
            section.Slides = NormalizeSlides(section.Slides);
            section.DisplayRules = NormalizeDisplayRules(section.DisplayRules);

            return section;
        }

        private static List<WebClientHomeCtaDto> NormalizeCtas(List<WebClientHomeCtaDto>? ctas)
        {
            ctas ??= new List<WebClientHomeCtaDto>();
            if (ctas.Count > MaxCtas)
                throw new ArgumentException($"CTAs cannot exceed {MaxCtas} per section or slide.");

            return ctas.Select(NormalizeCta).ToList();
        }

        private static WebClientHomeCtaDto NormalizeCta(WebClientHomeCtaDto cta)
        {
            if (cta == null)
                throw new ArgumentException("CTA is required.");

            cta.Text = NormalizeRequiredText(cta.Text, "CTA text", MaxTextLength);
            cta.Link = NormalizeRequiredUrl(cta.Link, "CTA link", allowExternal: true);
            cta.Style = NormalizeOptionalEnum(cta.Style, CtaStyles, "CTA style");
            ValidateCtaExternal(cta.Link, cta.External);
            return cta;
        }

        private static List<WebClientHomeSlideDto> NormalizeSlides(List<WebClientHomeSlideDto>? slides)
        {
            slides ??= new List<WebClientHomeSlideDto>();
            if (slides.Count > MaxSlides)
                throw new ArgumentException($"Slides cannot exceed {MaxSlides} per section.");

            return slides.Select(NormalizeSlide).ToList();
        }

        private static WebClientHomeSlideDto NormalizeSlide(WebClientHomeSlideDto slide)
        {
            if (slide == null)
                throw new ArgumentException("Slide is required.");

            slide.Title = NormalizeOptionalText(slide.Title, "Slide title", MaxTextLength);
            slide.Subtitle = NormalizeOptionalText(slide.Subtitle, "Slide subtitle", MaxTextLength);
            slide.ImageUrl = NormalizeOptionalImageUrl(slide.ImageUrl, "Slide image URL");
            slide.MobileImageUrl = NormalizeOptionalImageUrl(slide.MobileImageUrl, "Slide mobile image URL");
            slide.CtaText = NormalizeOptionalText(slide.CtaText, "Slide CTA text", MaxTextLength);
            slide.CtaLink = NormalizeOptionalUrl(slide.CtaLink, "Slide CTA link", allowExternal: true);
            slide.SecondaryCtaText = NormalizeOptionalText(slide.SecondaryCtaText, "Slide secondary CTA text", MaxTextLength);
            slide.SecondaryCtaLink = NormalizeOptionalUrl(slide.SecondaryCtaLink, "Slide secondary CTA link", allowExternal: true);
            slide.Ctas = NormalizeCtas(slide.Ctas);
            return slide;
        }

        private static WebClientHomeDisplayRulesDto? NormalizeDisplayRules(WebClientHomeDisplayRulesDto? rules)
        {
            if (rules == null)
                return null;

            rules.PortalMode = NormalizeOptionalEnum(rules.PortalMode, PortalModes, "Display rules portal mode");
            rules.ClientKeys = (rules.ClientKeys ?? new List<string>())
                .Select(key => NormalizeOptionalText(key, "Display rules client key", 50))
                .Where(key => !string.IsNullOrWhiteSpace(key))
                .Select(key => key!)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();
            return rules;
        }

        private static ResponsiveStringValueDto NormalizeResponsiveString(ResponsiveStringValueDto? value, HashSet<string> allowed, string label)
        {
            if (value == null)
                throw new ArgumentException($"{label} is required.");

            value.Desktop = NormalizeRequiredEnum(value.Desktop, allowed, $"{label} desktop");
            value.Tablet = NormalizeOptionalEnum(value.Tablet, allowed, $"{label} tablet");
            value.Mobile = NormalizeOptionalEnum(value.Mobile, allowed, $"{label} mobile");
            return value;
        }

        private static string NormalizeRequiredEnum(string? value, HashSet<string> allowed, string label)
        {
            var normalized = NormalizeOptionalText(value, label, 100);
            if (string.IsNullOrWhiteSpace(normalized) || !allowed.Contains(normalized))
                throw new ArgumentException($"{label} is invalid.");

            return normalized;
        }

        private static string? NormalizeOptionalEnum(string? value, HashSet<string> allowed, string label)
        {
            var normalized = NormalizeOptionalText(value, label, 100);
            if (string.IsNullOrWhiteSpace(normalized))
                return null;

            if (!allowed.Contains(normalized))
                throw new ArgumentException($"{label} is invalid.");

            return normalized;
        }

        private static string NormalizeRequiredText(string? value, string label, int maxLength)
        {
            var normalized = NormalizeOptionalText(value, label, maxLength);
            if (string.IsNullOrWhiteSpace(normalized))
                throw new ArgumentException($"{label} is required.");

            return normalized;
        }

        private static string? NormalizeOptionalText(string? value, string label, int maxLength)
        {
            if (value == null)
                return null;

            var normalized = value.Trim();
            if (normalized.Length == 0)
                return null;

            if (normalized.Length > maxLength)
                throw new ArgumentException($"{label} cannot exceed {maxLength} characters.");

            if (ContainsUnsafeText(normalized))
                throw new ArgumentException($"{label} contains unsafe content.");

            return normalized;
        }

        private static bool ContainsUnsafeText(string value)
        {
            return value.Contains("<script", StringComparison.OrdinalIgnoreCase)
                || value.Contains("javascript:", StringComparison.OrdinalIgnoreCase)
                || HtmlTagRegex.IsMatch(value);
        }

        private static string NormalizeRequiredUrl(string? value, string label, bool allowExternal)
        {
            var normalized = NormalizeOptionalUrl(value, label, allowExternal);
            if (string.IsNullOrWhiteSpace(normalized))
                throw new ArgumentException($"{label} is required.");

            return normalized;
        }

        private static string? NormalizeOptionalImageUrl(string? value, string label)
        {
            var normalized = NormalizeOptionalText(value, label, MaxUrlLength);
            if (string.IsNullOrWhiteSpace(normalized))
                return null;

            if (IsUnsafeUrl(normalized))
                throw new ArgumentException($"{label} is invalid.");

            if (normalized.StartsWith("/assets/", StringComparison.Ordinal)
                || normalized.StartsWith("/Images/", StringComparison.Ordinal)
                || normalized.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
                return normalized;

            throw new ArgumentException($"{label} must be an internal image path or HTTPS URL.");
        }

        private static string? NormalizeOptionalUrl(string? value, string label, bool allowExternal)
        {
            var normalized = NormalizeOptionalText(value, label, MaxUrlLength);
            if (string.IsNullOrWhiteSpace(normalized))
                return null;

            if (IsUnsafeUrl(normalized))
                throw new ArgumentException($"{label} is invalid.");

            if (normalized.StartsWith("/", StringComparison.Ordinal) && !normalized.StartsWith("//", StringComparison.Ordinal))
                return normalized;

            if (allowExternal && normalized.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
                return normalized;

            throw new ArgumentException(allowExternal
                ? $"{label} must be an internal path or HTTPS URL."
                : $"{label} must be an internal path.");
        }

        private static bool IsUnsafeUrl(string value)
        {
            return value.StartsWith("//", StringComparison.Ordinal)
                || value.StartsWith("javascript:", StringComparison.OrdinalIgnoreCase)
                || value.StartsWith("data:", StringComparison.OrdinalIgnoreCase);
        }

        private static void ValidateCtaExternal(string link, bool external)
        {
            var isExternalUrl = link.StartsWith("https://", StringComparison.OrdinalIgnoreCase);
            if (external && !isExternalUrl)
                throw new ArgumentException("External CTA links must use HTTPS URLs.");
        }

        private static int? NormalizeMaxItems(int? maxItems)
        {
            if (!maxItems.HasValue)
                return null;

            if (maxItems.Value <= 0 || maxItems.Value > MaxItems)
                throw new ArgumentException($"Max items must be between 1 and {MaxItems}.");

            return maxItems;
        }

        private static List<int> NormalizePositiveIds(List<int>? ids, string label)
        {
            ids ??= new List<int>();
            if (ids.Any(id => id <= 0))
                throw new ArgumentException($"{label} must be positive integers.");

            return ids.Distinct().ToList();
        }
    }
}
