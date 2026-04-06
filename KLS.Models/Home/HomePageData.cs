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
    }

    public class HomeCategory
    {
        public int CategoryId { get; set; }
        public string? CategoryName { get; set; }
        public string? DisplayName { get; set; }
        public string? ImageUrl { get; set; }
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
    }
}
