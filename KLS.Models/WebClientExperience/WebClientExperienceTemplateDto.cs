namespace KLS.Models.WebClientExperience
{
    public class WebClientExperienceTemplateDto
    {
        public string TemplateKey { get; set; } = string.Empty;

        public string DisplayName { get; set; } = string.Empty;

        public bool IsDefault { get; set; }
    }

    public class WebClientExperienceTemplateListDto
    {
        public List<WebClientExperienceTemplateDto> Templates { get; set; } = new();

        public bool HasDefault { get; set; }
    }

    public class WebClientExperienceTemplateActionDto
    {
        public string TemplateKey { get; set; } = string.Empty;

        public string Message { get; set; } = string.Empty;

        public WebClientHomeContentDto? HomeContent { get; set; }
    }
}
