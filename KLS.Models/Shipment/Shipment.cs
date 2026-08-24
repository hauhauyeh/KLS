using KLS.Common;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Reflection.Metadata.Ecma335;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class Shipment
    {
        public Shipment()
        {
            this.CreatedAt = DateTime.UtcNow;
        }

        [Key]
        public int ShipmentId { get; set; }

        [Required]
        [MaxLength(50)]
        public string ShipmentType { get; set; } = string.Empty;

        [MaxLength(30)]
        public string? ContainerNo { get; set; }

        [MaxLength(30)]
        public string? ContainerType { get; set; }

        [Required]
        public int PayeeId { get; set; }

        public string? DocumentNo { get; set; }

        [MaxLength(255)]
        public string? Origin { get; set; }

        [MaxLength(255)]
        public string? Destination { get; set; }

        public DateOnly? ETA { get; set; }

        public DateOnly? ETD { get; set; }

        [Required]
        [MaxLength(20)]
        public string Status { get; set; } = string.Empty;

        [MaxLength(50)]
        public string? DutyStatus { get; set; }

        public string? Notes { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }

        public bool AreChargesComplete { get; set; }

        public DateTime? ChargesCompletedAt { get; set; }

        public int? ChargesCompletedBy { get; set; }

        public bool IsLocked { get { return Status == EnumHelper.ShipmentStatus.Closed.ToString(); } }

        [NotMapped]
        public bool IsFreightSplitLocked { get; set; }

        [ForeignKey("ShipmentId")]
        public virtual ICollection<ShipmentCharge>? Charges { get; set; }
    }
}
