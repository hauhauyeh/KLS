using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class EmailLog
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int EmailLogId { get; set; }

        public int? PayeeId { get; set; }

        public string? EventType { get; set; }

        public string? Email { get; set; }

        public DateTime? SentDate { get; set; }

        public bool Status { get; set; }

        public string? ErrorMessage { get; set; }
    }
}
