namespace KLS.Models
{
    public class ImageFileResult
    {
        public string FilePath { get; set; } = string.Empty;

        public string FileName { get; set; } = string.Empty;

        public string ContentType { get; set; } = "application/octet-stream";
    }
}
