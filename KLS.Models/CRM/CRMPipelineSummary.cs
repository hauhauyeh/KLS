using System.ComponentModel.DataAnnotations;

namespace KLS.Models
{
    public class CRMPipelineSummary
    {
        [Key]
        public string Stage { get; set; } = string.Empty;

        public int Count { get; set; }
    }
}
