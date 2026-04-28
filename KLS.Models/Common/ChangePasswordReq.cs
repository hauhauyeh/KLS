namespace KLS.Models
{
    public class ChangePasswordReq
    {
        public string CurrentPassword { get; set; } = string.Empty;
        public string NewPassword { get; set; } = string.Empty;
    }
}
