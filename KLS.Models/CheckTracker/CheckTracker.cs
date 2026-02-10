using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class CheckTracker
    {
        [Key]
        public int CheckTrackerId { get; set; }

        public int AccountId { get; set; }

        public int CheckNumber { get; set; }
    }
}
