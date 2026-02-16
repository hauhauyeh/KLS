using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemImageList
    {
        [Key]
        public int ImageId { get; set; }

        public int ItemId { get; set; }

        public string? RelativeUrl { get; set; }

        public string? ThumbnailUrl { get; set; }

        public int SortOrder { get; set; }

        public bool IsPrimary { get; set; }
    }
}
