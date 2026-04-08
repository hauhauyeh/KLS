using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Text.Json.Serialization;

namespace KLS.Models
{
    public class RolePermission
    {
        public RolePermission()
        {
            this.GrantedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int RolePermissionId { get; set; }

        public int SystemRoleId { get; set; }

        public int PermissionId { get; set; }

        [JsonIgnore]
        public DateTime GrantedAt { get; set; }

        public int? GrantedBy { get; set; }
    }
}
