using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class AccountDTO
    {
        [Key]
        public int AccountId { get; set; }

        public string? TypeName { get; set; }

        public string? AccountCode { get; set; }

        public string? AccountName { get; set; }

        public bool Inactive { get; set; }

        public string? ClassName { get; set; }
    }
}
