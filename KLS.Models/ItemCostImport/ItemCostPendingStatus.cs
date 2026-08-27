using System;
using System.ComponentModel.DataAnnotations.Schema;

namespace KLS.Models
{
    /// <summary>The single row of Item_PendingCostStatus. Keyless.</summary>
    public class ItemCostPendingStatus
    {
        public int PendingUnits1 { get; set; }

        public int PendingUnits2 { get; set; }

        public byte? ScheduleDayOfWeek { get; set; }

        public string? ScheduleDayName { get; set; }

        public TimeSpan? ScheduleTime { get; set; }

        public bool? ScheduleEnabled { get; set; }

        public DateTime? NextApplyDate { get; set; }

        public bool AppliedToday { get; set; }

        public int? LastApplyId { get; set; }

        public DateTime? LastAppliedAt { get; set; }

        public string? LastTriggeredBy { get; set; }

        public int? LastUnitCount1 { get; set; }

        public int? LastUnitCount2 { get; set; }

        public bool CanApply { get; set; }

        public string? CannotApplyReason { get; set; }

        /// <summary>
        /// Date-only text. NextApplyDate is a SQL DATE; a DateTime would be
        /// shifted into the user's timezone by DateTimeMiddleware and could land
        /// on the previous day. The UI shows this.
        /// </summary>
        [NotMapped]
        public string? NextApplyDateText => NextApplyDate?.ToString("yyyy-MM-dd");
    }

    /// <summary>One row of Item_PendingCostImports. Keyless.</summary>
    public class ItemCostPendingImportRow
    {
        public int ImportId { get; set; }

        public int PayeeId { get; set; }

        public string? VendorName { get; set; }

        public byte Tier { get; set; }

        public string? FileName { get; set; }

        public DateTime? EffectiveFrom { get; set; }

        public DateTime? EffectiveTo { get; set; }

        public int FileRowCount { get; set; }

        public int UpdatedCount { get; set; }

        public int UnmappedCount { get; set; }

        public int MarketCount { get; set; }

        public DateTime CreatedAt { get; set; }

        public int? EmpId { get; set; }

        public string? EmpName { get; set; }

        [NotMapped]
        public string? EffectiveFromText => EffectiveFrom?.ToString("yyyy-MM-dd");

        [NotMapped]
        public string? EffectiveToText => EffectiveTo?.ToString("yyyy-MM-dd");
    }
}
