namespace KLS.Models
{
    public class UserAccountList
    {
        public int UserId { get; set; }
        public int RoleId { get; set; }
        public string RoleName { get; set; }
        public string Username { get; set; }
        public string Email { get; set; }
        public string? Phone { get; set; }
        public bool IsEmailVerified { get; set; }
        public bool IsPhoneVerified { get; set; }
        public bool Inactive { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}
