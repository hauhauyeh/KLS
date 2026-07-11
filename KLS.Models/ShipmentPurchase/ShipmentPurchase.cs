using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ShipmentPurchase
    {
        [Key]
        public int ShipmentPurchaseId { get; set; }

        public int ShipmentId { get; set; }

        public int PurchaseId { get; set; }

        // Per-bill redesign (Phase A): user-entered freight split inputs. BY_PALLET splits by PalletCount share;
        // BY_SPACE_PCT splits by SpacePercent/100. NULL until the split helper writes them.
        [Column(TypeName = "decimal(9,2)")]
        public decimal? PalletCount { get; set; }

        [Column(TypeName = "decimal(5,2)")]
        public decimal? SpacePercent { get; set; }
    }
}
