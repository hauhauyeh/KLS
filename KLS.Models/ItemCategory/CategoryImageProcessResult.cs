namespace KLS.Models
{
    public class CategoryImageProcessResult
    {
        public int CategoryId { get; set; }
        public string? OriginalUrl { get; set; }
        public string? PythonProcessedUrl { get; set; }
        public string? ApiProcessedUrl { get; set; }
    }
}
