using Microsoft.AspNetCore.Http;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemCategory
    {
        public ItemCategory()
        {
            this.CreatedAt = DateTime.UtcNow;
        }

        [Key]
        public int CategoryId { get; set; }

        public int? ParentId { get; set; }

        public string? CategoryName { get; set; }

        public string? DisplayName { get; set; }

        public string? ForeignName { get; set; }

        public string? InvoiceName { get; set; }

        public string? Description { get; set; }

        public string? Slug { get; set; }

        public string? ImageUrl { get; set; }

        public bool Inactive { get; set; }

        public int SortOrder { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? CustomDutyRate { get; set; }

        public DateTime? CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }

        [NotMapped]
        public IFormFile? CatFormFile { get; set; }
    }
}
