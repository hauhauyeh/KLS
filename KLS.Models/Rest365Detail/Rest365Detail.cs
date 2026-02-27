using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class Rest365Detail
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int RestDetailId { get; set; }

        public int Rest365Id { get; set; }

        public int? PayeeId { get; set; }

        public string? LocationNumber { get; set; }
    }
}
