using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Text.Json.Serialization;

namespace KLS.Models
{
    public class Permission
    {
        public Permission()
        {
            this.CreatedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int PermissionId { get; set; }

        public string PermissionKey { get; set; } = string.Empty;

        public string DisplayName { get; set; } = string.Empty;

        public string Module { get; set; } = string.Empty;

        public string Resource { get; set; } = string.Empty;

        public string Action { get; set; } = string.Empty;

        public string PermissionType { get; set; } = string.Empty;

        public string? ParentKey { get; set; }

        public int SortOrder { get; set; }

        public string? Description { get; set; }

        public string? OldKey { get; set; }

        public bool IsActive { get; set; } = true;

        [JsonIgnore]
        public DateTime CreatedAt { get; set; }
    }
}
