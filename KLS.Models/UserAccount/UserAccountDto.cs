namespace KLS.Models
{
    public class UserAccountDto
    {
        public int UserId { get; set; }
        public string Username { get; set; } = string.Empty;
        public string? Password { get; set; }
        public string Email { get; set; } = string.Empty;
        public string? Phone { get; set; }
        public bool Inactive { get; set; }
        public int RoleId { get; set; }
        public string? RoleName { get; set; }
    }
}
