using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class AmazonCatalogSearchResult
    {
        public int NumberOfResults { get; set; }
        public List<AmazonCatalogItem> Items { get; set; } = new();
        public AmazonPagination? Pagination { get; set; }
    }

    public class AmazonCatalogItem
    {
        public string Asin { get; set; } = string.Empty;
        public List<AmazonItemSummary>? Summaries { get; set; }
        public List<AmazonItemImageGroup>? Images { get; set; }
    }

    public class AmazonItemSummary
    {
        public string? MarketplaceId { get; set; }
        public string? ItemName { get; set; }
        public string? Brand { get; set; }
        public string? ProductType { get; set; }
    }

    public class AmazonItemImageGroup
    {
        public string? MarketplaceId { get; set; }
        public List<AmazonItemImage>? Images { get; set; }
    }

    public class AmazonItemImage
    {
        public string? Variant { get; set; }
        public string? Link { get; set; }
        public int? Height { get; set; }
        public int? Width { get; set; }
    }

    public class AmazonPagination
    {
        public string? NextToken { get; set; }
    }
}
