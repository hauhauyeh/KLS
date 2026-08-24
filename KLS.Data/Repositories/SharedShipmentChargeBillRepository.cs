using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System;
using System.Data;

namespace KLS.Data.Repositories
{
    public class SharedShipmentChargeBillRepository : KLSRepository<SharedShipmentChargeBill>, ISharedShipmentChargeBillRepository
    {
        public SharedShipmentChargeBillRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        public SharedShipmentChargeBillActionResult Apply(int sharedShipmentChargeBillId)
        {
            return RunAction("[dbo].[SharedShipmentChargeBill_Apply]", sharedShipmentChargeBillId);
        }

        public SharedShipmentChargeBillActionResult Void(int sharedShipmentChargeBillId)
        {
            return RunAction("[dbo].[SharedShipmentChargeBill_Void]", sharedShipmentChargeBillId);
        }

        private SharedShipmentChargeBillActionResult RunAction(string procedureName, int sharedShipmentChargeBillId)
        {
            var conn = DbContext.Database.GetDbConnection();
            var wasClosed = conn.State != ConnectionState.Open;

            if (wasClosed) conn.Open();
            try
            {
                using var cmd = conn.CreateCommand();
                cmd.CommandText = procedureName;
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add(new SqlParameter("@SharedShipmentChargeBillId", sharedShipmentChargeBillId));

                using var reader = cmd.ExecuteReader();
                if (!reader.Read())
                    throw new InvalidOperationException("Shared charge bill action did not return a result.");

                return new SharedShipmentChargeBillActionResult
                {
                    SharedShipmentChargeBillId = ReadInt(reader, "SharedShipmentChargeBillId"),
                    Status = ReadString(reader, "Status") ?? string.Empty,
                    GeneratedChildCount = ReadInt(reader, "GeneratedChildCount"),
                    RemovedChildCount = ReadInt(reader, "RemovedChildCount"),
                    AffectedShipmentCount = ReadInt(reader, "AffectedShipmentCount"),
                    Message = ReadString(reader, "Message") ?? string.Empty
                };
            }
            finally
            {
                if (wasClosed) conn.Close();
            }
        }

        private static int ReadInt(IDataRecord reader, string columnName)
        {
            var ordinal = TryGetOrdinal(reader, columnName);
            return ordinal < 0 || reader.IsDBNull(ordinal) ? 0 : Convert.ToInt32(reader.GetValue(ordinal));
        }

        private static string? ReadString(IDataRecord reader, string columnName)
        {
            var ordinal = TryGetOrdinal(reader, columnName);
            return ordinal < 0 || reader.IsDBNull(ordinal) ? null : Convert.ToString(reader.GetValue(ordinal));
        }

        private static int TryGetOrdinal(IDataRecord reader, string columnName)
        {
            for (var i = 0; i < reader.FieldCount; i++)
            {
                if (string.Equals(reader.GetName(i), columnName, StringComparison.OrdinalIgnoreCase))
                    return i;
            }

            return -1;
        }
    }
}
