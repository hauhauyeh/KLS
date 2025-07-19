using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Text.Json.Serialization;

namespace KLS.Models
{
    public class UserRole
    {
        public UserRole()
        {
            this.CreatedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int RoleId { get; set; }

        [Required(ErrorMessage = "Enter RoleName")]
        public string? RoleName { get; set; }

        [JsonIgnore]
        public string? RoleAccess { get; set; }

        public bool Inactive { get; set; }

        public bool IsDefault { get; set; }

        public bool IsAdmin { get; set; }

        public bool IsSalesRole { get; set; }

        public string? Notes { get; set; }

        public DateTime? CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
