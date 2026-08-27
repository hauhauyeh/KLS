using KLS.Models;
using System.Collections.Generic;

namespace KLS.Contract.Interfaces
{
    public interface IItemCostImportRepository
    {
        /// <summary>Read-only. Resolve uploaded rows (JSON) by unit barcode into statuses. Writes nothing.</summary>
        List<ItemCostImportRow> Preview(int tier, string rowsJson, out int notInFileCount);

        /// <summary>Stage pending costs in one transaction. Returns the import id, the units staged, and the not-in-file count.</summary>
        (int ImportId, int UpdatedUnitCount, int NotInFileCount) Import(int tier, string rowsJson, int empId, string fileName, string? effectiveFrom, string? effectiveTo);

        /// <summary>Read-only. Counts, schedule, last apply, CanApply + reason.</summary>
        ItemCostPendingStatus GetPendingStatus();

        /// <summary>Read-only. Imports not yet consumed by an apply.</summary>
        List<ItemCostPendingImportRow> GetPendingImports();

        /// <summary>Move pending -> live for every unit with a pending value. Guards are enforced by the SP.</summary>
        (int ApplyId, int UnitCount) ApplyPending(int empId);
    }
}
