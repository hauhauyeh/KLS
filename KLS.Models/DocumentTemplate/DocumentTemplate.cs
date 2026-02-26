using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class DocumentTemplate
    {
        public DocumentTemplate()
        {
            this.CreatedAt = DateTime.UtcNow;
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int DocTemplateId { get; set; }

        public string DocumentType { get; set; }

        public string DocumentName { get; set; }

        public string? Description { get; set; }

        public string HtmlContent { get; set; }

        public string? CssContent { get; set; }

        public string OrgHtmlContent { get; set; }

        public string? OrgCssContent { get; set; }

        public string? PaperSize { get; set; }

        public string? Orientation { get; set; }

        public int Version { get; set; }

        public bool IsActive { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
