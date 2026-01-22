using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class PrintLog
    {
        public PrintLog()
        {
            PrintReqAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int PrintLogId { get; set; }

        public string DocType { get; set; } = null!;

        public string PrintMode { get; set; } = null!;   // nvarchar(1)

        public string? DocPath { get; set; }

        public int? PageCount { get; set; }

        public bool IsInvoice { get; set; }

        public bool IsBOL { get; set; }

        public DateTime? PrintReqAt { get; set; }

        public bool IsPrinted { get; set; }

        public DateTime? PrintedAt { get; set; }
    }
}
