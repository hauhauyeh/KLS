using KLS.Models.WebClientExperience;

namespace KLS.Contract.Services
{
    public interface IWebClientExperienceService
    {
        WebClientHomeContentDto GetHomeContent();

        WebClientHomeContentDto UpdateHomeContent(WebClientHomeContentUpdateReq req);

        WebClientExperienceTemplateListDto GetTemplates();

        WebClientExperienceTemplateActionDto ResetHomeContentFromDefaultTemplate();

        WebClientExperienceTemplateActionDto LoadHomeContentFromTemplate(string templateKey);

        WebClientExperienceTemplateActionDto SaveCurrentProfileToTemplate(string templateKey);
    }
}
