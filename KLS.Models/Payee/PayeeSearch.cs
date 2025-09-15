using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class PayeeSearch
    {
        [Key]
        public int PayeeId { get; set; }

        public string? PayeeName { get; set; }

        public string? PayeeType { get; set; }

        public bool IsClosed { get; set; }
    }
}
