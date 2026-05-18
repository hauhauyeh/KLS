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
    ///   - "{BaseUnit}/{Factor}{AltUnit}" when an active alt unit exists
    ///   - "{BaseUnit}" when no active alt unit (or alt has invalid factor)
    ///   - Factor uses "0.######" so trailing zeros from decimal(18,6) are stripped
    ///     (e.g. 6.000000 -> "6", 5.500000 -> "5.5")
    ///   - "Active alt" = first non-base, non-inactive unit ordered by ItemUnitId
    ///     (creation order)
    /// </summary>
    public static class SetPackingFormatter
    {
        public static string Format(IEnumerable<ItemUnit> units)
        {
            var list = units?.ToList() ?? new List<ItemUnit>();

            var baseUnit = list.FirstOrDefault(u => u.IsBaseUnit);
            if (baseUnit == null || string.IsNullOrWhiteSpace(baseUnit.Unit))
                return string.Empty;

            // First non-base, non-inactive alt in creation order.
            var alt = list
                .Where(u => !u.IsBaseUnit && !u.Inactive)
                .OrderBy(u => u.ItemUnitId)
                .FirstOrDefault();

            if (alt == null || string.IsNullOrWhiteSpace(alt.Unit) || alt.FactorToBase <= 0)
                return baseUnit.Unit;

            var factorStr = alt.FactorToBase
                .ToString("0.######", CultureInfo.InvariantCulture);

            return $"{baseUnit.Unit}/{factorStr}{alt.Unit}";
        }
    }
}
