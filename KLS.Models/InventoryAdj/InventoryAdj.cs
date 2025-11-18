using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Security.Principal;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class InventoryAdj
    {
        public InventoryAdj()
        {
            this.CreatedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int AdjId { get; set; }

        public int AdjNumber { get; set; }

        public DateOnly? AdjDate { get; set; }

        public string? AdjType { get; set; }

        public string? Notes { get; set; }

        public bool IsLocked { get; set; }

        public string? OpenClose { get; set; }

        public DateTime? CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
