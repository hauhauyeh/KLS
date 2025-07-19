using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class User
    {
        public User()
        {
            this.CreatedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int UserId { get; set; }
        public int RoleId { get; set; }
        public int PayeeId { get; set; }

        public string? Username { get; set; }

        [JsonIgnore]
        public string? PasswordHash { get; set; }

        public bool Inactive { get; set; }

        [JsonIgnore]
        public string? RefToken { get; set; }

        [JsonIgnore]
        public DateTime? RefTokenExpire { get; set; }

        public DateTime? CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }
    }
}
