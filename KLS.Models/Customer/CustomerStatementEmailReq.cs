using KLS.Models.Reports;
using System.Text.Json.Serialization;

namespace KLS.Models
{
    public class CustomerStatementEmailReq
    {
        public string? RecipientEmail { get; set; }

        [JsonConverter(typeof(JsonStringEnumConverter))]
        public StatementScope? Scope { get; set; }
    }
}
