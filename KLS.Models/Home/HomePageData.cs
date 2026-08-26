using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class HomePageData
    {
        public IEnumerable<HomeCategory>? Categories { get; set; }
        public IEnumerable<HomeProduct>? Products { get; set; }

        public IEnumerable<HomeCategory>? FeaturedCategories { get; set; }
        public IEnumerable<HomeProduct>? NewArrivals { get; set; }
        public IEnumerable<HomeProduct>? TopSellingProducts { get; set; }
        public IEnumerable<HomeCategoryProductGroup>? TopCategoryGroups { get; set; }
    }

    public class HomeCategory
    {
        public int CategoryId { get; set; }
        public string? CategoryName { get; set; }
        public string? DisplayName { get; set; }
        public string? ImageUrl { get; set; }
        public string? ThumbnailUrl { get; set; }
        public string? WebImageUrl { get; set; }
        public string? NoBgThumbnailUrl { get; set; }
        public string? NoBgWebImageUrl { get; set; }
        public string? OriginalUrl { get; set; }
        public int ItemCount { get; set; }
    }

    public class HomeProduct
    {
        public int ItemId { get; set; }
        public string? ItemName { get; set; }
        public string? ItemName2 { get; set; }
        public string? SetPacking { get; set; }
        public string? PackSize { get; set; }
        public string? PrimaryImageUrl { get; set; }
        public int? CategoryId { get; set; }
        public string? CategoryName { get; set; }
        public string? BadgeText { get; set; }
    }

    public class HomeCategoryProductGroup
    {
        public int CategoryId { get; set; }
        public string? CategoryName { get; set; }
        public string? DisplayName { get; set; }
        public string? ImageUrl { get; set; }
        public string? ThumbnailUrl { get; set; }
        public string? WebImageUrl { get; set; }
        public string? NoBgThumbnailUrl { get; set; }
        public string? NoBgWebImageUrl { get; set; }
        public string? OriginalUrl { get; set; }
        public int ItemCount { get; set; }
        public string? Subtitle { get; set; }
        public IEnumerable<HomeProduct>? Products { get; set; }
    }
}
