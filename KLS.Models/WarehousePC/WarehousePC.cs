using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace KLS.Models
{
    public class WarehousePC
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int WarehousePCId { get; set; }
        public string? IPAddress { get; set; }
        public string? PrinterName { get; set; }
    }
}
