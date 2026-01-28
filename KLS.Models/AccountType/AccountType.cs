using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class AccountType
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int AccountTypeId { get; set; }

        public string AccountClass { get; set; }

        public string TypeName { get; set; }

        public string? TypeNumber { get; set; }

        public string? DetailType { get; set; }

        public string? DetailNumber { get; set; }

        public int? SortOrder { get; set; }

        public bool Inactive { get; set; }

        public string? Notes { get; set; }
    }
}
