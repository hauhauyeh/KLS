using KLS.Common;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ShipmentList
    {
        [Key]
        public int ShipmentId { get; set; }

        public string ShipmentType { get; set; } = string.Empty;

        public string? ContainerNo { get; set; }

        public string? ContainerType { get; set; }

        public int PayeeId { get; set; }

        public string? DocumentNo { get; set; }

        public string PayeeName { get; set; } = string.Empty;

        public string? Origin { get; set; }

        public string? Destination { get; set; }

        public DateOnly? ETA { get; set; }

        public string Status { get; set; } = string.Empty;

        public string? Notes { get; set; }

        public bool IsLocked { get { return Status == EnumHelper.ShipmentStatus.Closed.ToString(); } }

        public decimal? TotalCharges { get; set; }
    }
}
