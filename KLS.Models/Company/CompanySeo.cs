using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace KLS.Models
{
    public class CompanySeo
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int CompanySeoId { get; set; }

        public int? CompanyId { get; set; }

        public string? MetaTitle { get; set; }

        public string? MetaTitleShort { get; set; }

        public string? MetaDesc { get; set; }

        public string? Keywords { get; set; }

        public string? GoogleTagId { get; set; }

        public string? JsonLd { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
