namespace KLS.Models.WebClientExperience
{
    public class WebClientHomeContentDto
    {
        public WebClientHomeDto Home { get; set; } = WebClientHomeDto.Default();

        public WebClientHomeLayoutDto HomeLayout { get; set; } = WebClientHomeLayoutDto.Default();

        public bool HasProfile { get; set; }
    }

    public class WebClientHomeContentUpdateReq
    {
        public WebClientHomeDto Home { get; set; } = WebClientHomeDto.Default();

        public WebClientHomeLayoutDto HomeLayout { get; set; } = WebClientHomeLayoutDto.Default();
    }

    public class WebClientHomeDto
    {
        public string? Mode { get; set; }

        public string? ExternalHomeUrl { get; set; }

        public string? PostLoginRedirect { get; set; }

        public string? Preset { get; set; }

        public List<WebClientHomeSectionDto> Sections { get; set; } = new();

        public static WebClientHomeDto Default()
        {
            return new WebClientHomeDto
            {
                Mode = "internal",
                Preset = "catalog-first",
                Sections = new List<WebClientHomeSectionDto>()
            };
        }
    }

    public class WebClientHomeLayoutDto
    {
        public ResponsiveStringValueDto Width { get; set; } = new() { Desktop = "contained" };

        public ResponsiveStringValueDto Preset { get; set; } = new() { Desktop = "catalog-first" };

        public ResponsiveBoolValueDto ShowServiceStrip { get; set; } = new() { Desktop = false };

        public static WebClientHomeLayoutDto Default()
        {
            return new WebClientHomeLayoutDto();
        }
    }

    public class ResponsiveStringValueDto
    {
        public string? Desktop { get; set; }

        public string? Tablet { get; set; }

        public string? Mobile { get; set; }
    }

    public class ResponsiveBoolValueDto
    {
        public bool Desktop { get; set; }

        public bool? Tablet { get; set; }

        public bool? Mobile { get; set; }
    }

    public class WebClientHomeSectionDto
    {
        public string? Type { get; set; }

        public string? Title { get; set; }

        public string? Subtitle { get; set; }

        public string? Body { get; set; }

        public string? ImageUrl { get; set; }

        public string? MobileImageUrl { get; set; }

        public string? MediaType { get; set; }

        public string? VideoUrl { get; set; }

        public string? CtaText { get; set; }

        public string? CtaLink { get; set; }

        public string? SecondaryCtaText { get; set; }

        public string? SecondaryCtaLink { get; set; }

        public List<WebClientHomeCtaDto> Ctas { get; set; } = new();

        public List<int> CategoryIds { get; set; } = new();

        public List<int> ItemIds { get; set; } = new();

        public string? Source { get; set; }

        public int? MaxItems { get; set; }

        public WebClientHomeDisplayRulesDto? DisplayRules { get; set; }

        public List<WebClientHomeSlideDto> Slides { get; set; } = new();

        public bool Disabled { get; set; }
    }

    public class WebClientHomeCtaDto
    {
        public string? Text { get; set; }

        public string? Link { get; set; }

        public string? Style { get; set; }

        public bool External { get; set; }
    }

    public class WebClientHomeDisplayRulesDto
    {
        public bool RequiresLogin { get; set; }

        public string? PortalMode { get; set; }

        public List<string> ClientKeys { get; set; } = new();
    }

    public class WebClientHomeSlideDto
    {
        public string? Title { get; set; }

        public string? Subtitle { get; set; }

        public string? ImageUrl { get; set; }

        public string? MobileImageUrl { get; set; }

        public string? CtaText { get; set; }

        public string? CtaLink { get; set; }

        public string? SecondaryCtaText { get; set; }

        public string? SecondaryCtaLink { get; set; }

        public List<WebClientHomeCtaDto> Ctas { get; set; } = new();
    }
}
