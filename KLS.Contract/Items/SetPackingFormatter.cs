using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using KLS.Models;

namespace KLS.Contract.Items
{
    /// <summary>
    /// Pure formatter that turns an item's ItemUnit collection into the canonical
    /// SetPacking string. No database access. No side effects.
    ///
    /// Format rules:
    ///   - "{BaseUnit}/{Factor}{AltUnit}" only when base unit is case/carton-like
    ///     (cs, case, carton, ctn, crt) and an active split alt unit exists
    ///   - null values when the unit structure does not express meaningful packing
    ///   - Factor uses "0.######" so trailing zeros from decimal(18,6) are stripped
    ///     (e.g. 6.000000 -> "6", 5.500000 -> "5.5")
    ///   - "Active alt" = first non-base, non-inactive unit ordered by ItemUnitId
    ///     (creation order)
    /// </summary>
    public static class SetPackingFormatter
    {
        private static readonly HashSet<string> CaseUnits = new()
        {
            "cs",
            "case",
            "carton",
            "ctn",
            "crt"
        };

        public static SetPackingFormatResult Format(IEnumerable<ItemUnit> units)
        {
            var list = units?.ToList() ?? new List<ItemUnit>();

            var baseUnit = list.FirstOrDefault(u => u.IsBaseUnit);
            if (baseUnit == null || string.IsNullOrWhiteSpace(baseUnit.Unit))
                return SetPackingFormatResult.Empty;

            var baseUnitName = baseUnit.Unit.Trim();
            if (!CaseUnits.Contains(baseUnitName.ToLowerInvariant()))
                return SetPackingFormatResult.Empty;

            // First non-base, non-inactive alt in creation order.
            var alt = list
                .Where(u => !u.IsBaseUnit && !u.Inactive)
                .OrderBy(u => u.ItemUnitId)
                .FirstOrDefault();

            if (alt == null || string.IsNullOrWhiteSpace(alt.Unit) || alt.FactorToBase <= 1)
                return SetPackingFormatResult.Empty;

            var altUnitName = alt.Unit.Trim();
            if (CaseUnits.Contains(altUnitName.ToLowerInvariant()))
                return SetPackingFormatResult.Empty;

            var factorStr = alt.FactorToBase
                .ToString("0.######", CultureInfo.InvariantCulture);

            var packSize = $"{factorStr}{altUnitName}";
            return new SetPackingFormatResult($"{baseUnitName}/{packSize}", packSize);
        }
    }

    public record SetPackingFormatResult(string? SetPacking, string? PackSize)
    {
        public static SetPackingFormatResult Empty { get; } = new(null, null);
    }
}
