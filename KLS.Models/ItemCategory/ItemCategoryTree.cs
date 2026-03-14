using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemCategoryTree
    {
        [Key]
        public int CategoryId { get; set; }

        public int? ParentId { get; set; }

        public string? CategoryName { get; set; }

        public string? DisplayName { get; set; }

        public string? ImageUrl { get; set; }

        public IEnumerable<ItemCategoryTree>? ChildCategories { get; set; }
        
        public bool HasChild { get { return ChildCategories != null && ChildCategories.Any(); } }

        public int ItemCount { get; set; }
    }
}
