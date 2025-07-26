using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class RecalculationQAVLog
    {
        [Key]
        public Int64 LogId { get; set; }

        public string? ItemCode { get; set; }

        public Int64 TransactionNumber { get; set; }

        public DateOnly TransactionDate { get; set; }

        public bool IsDeleted { get; set; }
    }
}
