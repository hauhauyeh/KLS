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

        public int SortOrder { get; set; }

        public bool IsPrimary { get; set; }

        public int ImageIndex { get; set; }

        public string? OriginalExtension { get; set; }

        public bool IsProcessed { get; set; }

        public bool IsProcessing { get; set; }

        // Per-version file existence flags
        public bool Has300 { get; set; }
        public bool Has1200 { get; set; }
        public bool Has2000 { get; set; }
        public bool HasNoBg300 { get; set; }
        public bool HasNoBg1200 { get; set; }

        public DateTime CreatedAt { get; set; }
    }
}
