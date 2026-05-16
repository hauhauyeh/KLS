using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace KLS.Models
{
    public class BankFeedAccount
    {
        public BankFeedAccount()
        {
            ImportFormat = "CSV";
            IsActive = true;
            CreatedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public long BankFeedAccountId { get; set; }

        public int AccountId { get; set; }

        public string? AccountNickname { get; set; }

        public string ImportFormat { get; set; } = "CSV";

        public bool IsActive { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
