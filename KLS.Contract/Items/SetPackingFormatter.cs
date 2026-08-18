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
    ///     (cs, case, carton, ctn, crt) and an active smaller split alt unit exists
    ///   - otherwise the base unit name is the canonical SetPacking
    ///   - null only when no valid base unit exists
    ///   - Factor uses "0.######" so trailing zeros from decimal(18,6) are stripped
    ///     (e.g. 6.000000 -> "6", 5.500000 -> "5.5")
    ///   - "Split alt" = first active smaller non-base unit ordered by ItemUnitId
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
                return new SetPackingFormatResult(baseUnitName, null);

            // First active smaller split alt in creation order.
            var alt = list
                .Where(u => !u.IsBaseUnit
                    && !u.Inactive
                    && !string.IsNullOrWhiteSpace(u.Unit)
                    && u.FactorToBase > 1
                    && u.MultipleToBase == 1
                    && !CaseUnits.Contains(u.Unit.Trim().ToLowerInvariant()))
                .OrderBy(u => u.ItemUnitId)
                .FirstOrDefault();

            if (alt == null)
                return new SetPackingFormatResult(baseUnitName, null);

            var altUnitName = alt.Unit.Trim();
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
