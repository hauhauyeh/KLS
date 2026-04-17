using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Text.Json.Serialization;

namespace KLS.Models
{
    public class Term
    {
        public Term()
        {
            this.CreatedAt = DateTime.UtcNow;
        }

        public int TermId { get; set; }

        // Required + trim => backing field
        private string _termName = string.Empty;
        public string TermName
        {
            get => _termName;
            set
            {
                if (string.IsNullOrWhiteSpace(value))
                    throw new ArgumentException("TermName is required.", nameof(TermName));

                _termName = value.Trim();
            }
        }

        // No strict rule? keep simple
        public string? TermType { get; set; }

        public string? TermGroup { get; set; }

        public int? DueDays { get; set; }

        // Must not be negative => backing field
        private decimal? _discount;
        public decimal? Discount
        {
            get => _discount;
            set
            {
                if (value.HasValue && value.Value < 0)
                    throw new ArgumentException("Discount cannot be negative.", nameof(Discount));

                _discount = value;
            }
        }

        public bool Inactive { get; set; }

        public bool IsSystem { get; set; }

        public string? Notes { get; set; }

        [JsonIgnore]
        public DateTime CreatedAt { get; set; }

        [JsonIgnore]
        public DateTime? UpdatedAt { get; set; }

        // ---------------- Encapsulated behavior ----------------

        /// <summary>
        /// Use this from service to update safely (instead of setting 7 fields manually).
        /// Validation runs via property setters; UpdatedAt is always set.
        /// </summary>
        public void UpdateTerm(Term source)
        {
            if (source == null) throw new ArgumentNullException(nameof(source));

            TermName = source.TermName;
            TermType = source.TermType;
            TermGroup = source.TermGroup;
            DueDays = source.DueDays;
            Discount = source.Discount;
            Inactive = source.Inactive;
            Notes = source.Notes;

            Touch();
        }

        public void Activate()
        {
            Inactive = false;
            Touch();
        }

        public void Deactivate()
        {
            Inactive = true;
            Touch();
        }

        private void Touch()
        {
            UpdatedAt = DateTime.UtcNow;
        }
    }
}
