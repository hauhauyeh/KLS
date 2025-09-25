using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class DeleteLog
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int LogId { get; set; }

        public DateTime? LogDate { get; set; }

        public string? SourceDocType { get; set; }

        public int? SourceDocNum { get; set; }

        public int? DeletedBy { get; set; }
    }
}
