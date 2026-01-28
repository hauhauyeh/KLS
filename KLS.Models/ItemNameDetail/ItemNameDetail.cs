using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Reflection.Metadata.Ecma335;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemNameDetail
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int ItemNameId { get; set; }

        public int ItemId { get; set; }

        public string? LanguageCode { get; set; }

        public string? NameContext { get; set; }

        public string? NameText { get; set; }
    }
}
