using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ChartOfAccountType
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int AccountTypeId { get; set; }

        public string? AccountType { get; set; }

        public string? TypeNumber { get; set; }

        public string? CatName { get; set; }

        public string? CatNumber { get; set; }

        public string? ReportGrp0 { get; set; }

        public string? ReportGrp1 { get; set; }

        public string? ReportGrp2 { get; set; }

        public string? ReportGrp3 { get; set; }
    }
}
