using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models.Reports
{
    public class RptBalanceSheetRow
    {
        public string? ClassCode { get; set; }

        public string? ClassName { get; set; }

        public string? CategoryLevel0 { get; set; }

        public string? CategoryLevel1 { get; set; }

        public string? CategoryLevel2 { get; set; }

        public string? CategoryLevel3 { get; set; }

        public int? CategorySort0 { get; set; }

        public int? CategorySort1 { get; set; }

        public int? CategorySort2 { get; set; }

        public int? CategorySort3 { get; set; }

        public int? AccountSortOrder { get; set; }

        [Key]
        public int? AccountId { get; set; }

        public string? AccountCode { get; set; }

        public string? AccountName { get; set; }

        [Column(TypeName = "money")]
        public decimal? ClosingBalance { get; set; }
    }
}
