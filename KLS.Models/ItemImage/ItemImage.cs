using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemImage
    {
        public ItemImage()
        {
            this.CreatedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int ImageId { get; set; }

        public int ItemId { get; set; }

        public string? FileName { get; set; }

        public string? RelativePath { get; set; }

        public string? ThumbnailPath { get; set; }

        public int SortOrder { get; set; }

        public bool IsPrimary { get; set; }

        public DateTime CreatedAt { get; set; }
    }
}
