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
    public class SystemUser
    {
        public SystemUser()
        {
            this.CreatedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int SystemUserId { get; set; }

        public int SystemRoleId { get; set; }

        public int PayeeId { get; set; }

        public string? Email { get; set; }

        public string? Username { get; set; }

        [JsonIgnore]
        public string? PasswordHash { get; set; }

        public bool Inactive { get; set; }

        public string? RefToken { get; set; }

        public DateTime? RefTokenExpire { get; set; }

        public string? ResetTokenHash { get; set; }

        public DateTime? ResetTokenExpire { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
