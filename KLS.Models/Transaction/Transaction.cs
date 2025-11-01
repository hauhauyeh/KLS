using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class Transaction
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public Int64 TxId { get; set; }

        //public int TxNumber { get; set; }

        public DateOnly TxDate { get; set; }

        public DateTime? TxTime { get; set; }

        public int? SourceDocOrder { get; set; }

        public string? SourceDocType { get; set; }

        public int? SourceDocNumber { get; set; }

        public string? Notes { get; set; }

        public bool IsLocked { get; set; }

        public DateOnly? BankDate { get; set; }
    }
}
