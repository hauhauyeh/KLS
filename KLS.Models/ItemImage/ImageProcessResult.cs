namespace KLS.Models
{
    public class ImageProcessResult
    {
        public int ImageId { get; set; }
        public int ItemId { get; set; }
        public int ImageIndex { get; set; }
        public string? OriginalUrl { get; set; }
        public string? PythonProcessedUrl { get; set; }
        public string? ApiProcessedUrl { get; set; }
    }
}
