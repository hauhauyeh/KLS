using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace KLS.Models
{
    public class LabelPrintLog
    {
        public LabelPrintLog()
        {
            PrintReqTime = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int PrintLogId { get; set; }
        public DateTime? PrintReqTime { get; set; }
        public string? IPAddress { get; set; }
        public string? PrinterName { get; set; }
        public string? PrintContent { get; set; }
        public int? PrintCopy { get; set; }
        public bool IsCenter { get; set; }
        public bool IsPrinted { get; set; }
        public DateTime? PrintedAt { get; set; }
    }
}
