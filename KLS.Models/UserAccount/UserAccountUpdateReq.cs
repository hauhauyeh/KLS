using System.ComponentModel.DataAnnotations;

namespace KLS.Models
{
    public class UserAccountUpdateReq
    {
        [Required]
        public int UserId { get; set; }

        [Required]
        public int RoleId { get; set; }

        [Required]
        public string Username { get; set; }

        public bool Inactive { get; set; }
    }
}
