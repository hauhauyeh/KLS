using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class UserLog
    {
        public UserLog()
        {
            CreatedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int UserLogId { get; set; }

        public int PayeeId { get; set; }

        public string? IPAddress { get; set; }

        public DateTime? CreatedAt { get; set; }
    }
}
