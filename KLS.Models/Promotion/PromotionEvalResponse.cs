namespace KLS.Models
{
    public class PromotionEvalResponse
    {
        public List<PromotionEvalResult> AvailablePromotions { get; set; } = new();
        public List<string> DebugLog { get; set; } = new();
    }
}
