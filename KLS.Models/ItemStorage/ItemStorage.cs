using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemStorage
    {
        public ItemStorage()
        {
            CreatedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int StorageId { get; set; }

        public string? DisplayName { get; set; }

        public int? SortOrder { get; set; }

        public string? Zone { get; set; }

        public string? Section { get; set; }

        public string? Aisle { get; set; }

        public string? Bay { get; set; }

        public string? Bin { get; set; }

        public bool Inactive { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
