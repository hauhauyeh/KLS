using System.ComponentModel.DataAnnotations;

namespace KLS.Models
{
    public class ItemImageList
    {
        [Key]
        public int ImageId { get; set; }

        public int ItemId { get; set; }

        public int ImageIndex { get; set; }

        public int SortOrder { get; set; }

        public bool IsPrimary { get; set; }

        public bool IsProcessed { get; set; }

        public int ImageCount { get; set; }

        public int? OriginalWidth { get; set; }

        public int? OriginalHeight { get; set; }

        public int? EffectiveSourceWidth { get; set; }

        public int? EffectiveSourceHeight { get; set; }

        // With-bg URLs
        public string? ThumbnailUrl { get; set; }       // {index}-300.png

        public string? Url900 { get; set; }              // {index}-900.png

        public string? Url1600 { get; set; }             // {index}-1600.png

        public string? Url2200 { get; set; }             // {index}-2200.png

        public string? Url1200 { get; set; }             // {index}-1200.png

        public string? Url2000 { get; set; }             // {index}-2000.png

        // No-bg URLs (null when !IsProcessed)
        public string? NoBgThumbnailUrl { get; set; }    // {index}-300-nobg.png

        public string? NoBg900Url { get; set; }          // {index}-900-nobg.png

        public string? NoBg1200Url { get; set; }         // {index}-1200-nobg.png

        // Original
        public string? OriginalUrl { get; set; }         // {index}-org.{ext}
    }
}
