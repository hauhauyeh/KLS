using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class Rest365
    {
        public Rest365()
        {
            this.CreatedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Rest365Id { get; set; }

        public string? CustomerName { get; set; }

        public string? Host { get; set; }

        public string? Username { get; set; }

        public string? Password { get; set; }

        public string? FolderPath { get; set; }

        public bool Inactive { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
