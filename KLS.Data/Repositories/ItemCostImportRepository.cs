using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;

namespace KLS.Data.Repositories
{
    public class ItemCostImportRepository : IItemCostImportRepository
    {
        private readonly KLSDBContext DbContext;

        public ItemCostImportRepository(KLSDBContext dbContext)
        {
            DbContext = dbContext;
        }

        public List<ItemCostImportRow> Preview(int tier, string rowsJson, out int notInFileCount)
        {
            var tierParam = new SqlParameter("@Tier", (byte)tier);
            var rowsParam = new SqlParameter("@RowsJson", SqlDbType.NVarChar, -1) { Value = rowsJson };

            var notInFileParam = new SqlParameter
            {
                ParameterName = "@NotInFileCount",
                Direction = ParameterDirection.Output,
                SqlDbType = SqlDbType.Int
            };

            // Output parameters are populated once the reader is fully consumed (ToList).
            var rows = Translate(() => DbContext.ItemCostImportRow
                .FromSqlRaw("[dbo].[Item_ImportCostPreview] @Tier,@RowsJson,@NotInFileCount OUTPUT", tierParam, rowsParam, notInFileParam)
                .ToList());

            notInFileCount = notInFileParam.Value is int n ? n : Convert.ToInt32(notInFileParam.Value ?? 0);

            return rows;
        }

        public (int ImportId, int UpdatedUnitCount, int NotInFileCount) Import(int tier, string rowsJson, int empId, string fileName, string? effectiveFrom, string? effectiveTo)
        {
            var tierParam = new SqlParameter("@Tier", (byte)tier);
            var rowsParam = new SqlParameter("@RowsJson", SqlDbType.NVarChar, -1) { Value = rowsJson };
            var empIdParam = new SqlParameter("@EmpId", empId);
            var fileNameParam = new SqlParameter("@FileName", (object?)fileName ?? DBNull.Value);
            var fromParam = new SqlParameter("@EffectiveFrom", SqlDbType.Date) { Value = (object?)effectiveFrom ?? DBNull.Value };
            var toParam = new SqlParameter("@EffectiveTo", SqlDbType.Date) { Value = (object?)effectiveTo ?? DBNull.Value };

            var importIdParam = new SqlParameter
            {
                ParameterName = "@ImportId",
                Direction = ParameterDirection.Output,
                SqlDbType = SqlDbType.Int
            };

            var updatedParam = new SqlParameter
            {
                ParameterName = "@UpdatedCount",
                Direction = ParameterDirection.Output,
                SqlDbType = SqlDbType.Int
            };

            var notInFileParam = new SqlParameter
            {
                ParameterName = "@NotInFileCount",
                Direction = ParameterDirection.Output,
                SqlDbType = SqlDbType.Int
            };

            Translate(() => DbContext.Database.ExecuteSqlRaw(
                "[dbo].[Item_ImportCost] @Tier,@RowsJson,@EmpId,@FileName,@EffectiveFrom,@EffectiveTo,@ImportId OUTPUT,@UpdatedCount OUTPUT,@NotInFileCount OUTPUT",
                tierParam, rowsParam, empIdParam, fileNameParam, fromParam, toParam, importIdParam, updatedParam, notInFileParam));

            return (Convert.ToInt32(importIdParam.Value), Convert.ToInt32(updatedParam.Value), Convert.ToInt32(notInFileParam.Value));
        }

        public ItemCostPendingStatus GetPendingStatus()
        {
            return DbContext.ItemCostPendingStatus
                .FromSqlRaw("[dbo].[Item_PendingCostStatus]")
                .AsEnumerable()
                .First();
        }

        public List<ItemCostPendingImportRow> GetPendingImports()
        {
            return DbContext.ItemCostPendingImportRow
                .FromSqlRaw("[dbo].[Item_PendingCostImports]")
                .ToList();
        }

        public (int ApplyId, int UnitCount) ApplyPending(int empId)
        {
            var triggeredByParam = new SqlParameter("@TriggeredBy", "MANUAL");
            var empIdParam = new SqlParameter("@EmpId", empId);

            var applyIdParam = new SqlParameter
            {
                ParameterName = "@ApplyId",
                Direction = ParameterDirection.Output,
                SqlDbType = SqlDbType.Int
            };

            var unitCountParam = new SqlParameter
            {
                ParameterName = "@UnitCount",
                Direction = ParameterDirection.Output,
                SqlDbType = SqlDbType.Int
            };

            Translate(() => DbContext.Database.ExecuteSqlRaw(
                "[dbo].[Item_ApplyPendingCost] @TriggeredBy,@EmpId,@ApplyId OUTPUT,@UnitCount OUTPUT",
                triggeredByParam, empIdParam, applyIdParam, unitCountParam));

            return (Convert.ToInt32(applyIdParam.Value), Convert.ToInt32(unitCountParam.Value));
        }

        // 2026-08-29 plan-reprice-open-orders-v1 slice 4. Plain ADO reader (same pattern as
        // OpenBalanceRepository): the SP returns the skipped/errored orders as a result set and
        // the counts as OUTPUT params; output values are valid only after the reader is closed.
        public SalesRepriceResult RepriceOpenOrders(string triggeredBy, int? empId, int? applyId)
        {
            var connection = DbContext.Database.GetDbConnection();
            var closeConnection = connection.State != ConnectionState.Open;

            using var command = connection.CreateCommand();
            command.CommandText = "[dbo].[Sales_RepriceOpenOrders]";
            command.CommandType = CommandType.StoredProcedure;

            var repriceIdParam = OutInt("@RepriceId");
            var orderCountParam = OutInt("@OrderCount");
            var lineCountParam = OutInt("@LineCount");
            var skippedCountParam = OutInt("@SkippedCount");

            command.Parameters.Add(new SqlParameter("@TriggeredBy", triggeredBy));
            command.Parameters.Add(new SqlParameter("@EmpId", (object?)empId ?? DBNull.Value));
            command.Parameters.Add(new SqlParameter("@ApplyId", (object?)applyId ?? DBNull.Value));
            command.Parameters.Add(new SqlParameter("@SalesId", DBNull.Value));
            command.Parameters.Add(repriceIdParam);
            command.Parameters.Add(orderCountParam);
            command.Parameters.Add(lineCountParam);
            command.Parameters.Add(skippedCountParam);

            if (closeConnection)
                connection.Open();

            var skipped = new List<SalesRepriceSkippedRow>();

            try
            {
                Translate(() =>
                {
                    using var reader = command.ExecuteReader();
                    while (reader.Read())
                    {
                        skipped.Add(new SalesRepriceSkippedRow
                        {
                            SalesId = reader.GetInt32(reader.GetOrdinal("SalesId")),
                            SalesNumber = reader.GetInt32(reader.GetOrdinal("SalesNumber")),
                            StageId = reader.GetInt32(reader.GetOrdinal("StageId")),
                            Reason = reader.GetString(reader.GetOrdinal("Reason"))
                        });
                    }
                    return 0;
                });
            }
            finally
            {
                if (closeConnection)
                    connection.Close();
            }

            return new SalesRepriceResult
            {
                RepriceId = Convert.ToInt32(repriceIdParam.Value),
                OrderCount = Convert.ToInt32(orderCountParam.Value),
                LineCount = Convert.ToInt32(lineCountParam.Value),
                SkippedCount = Convert.ToInt32(skippedCountParam.Value),
                ErrorCount = skipped.Count(r => r.Reason.StartsWith("Error:", StringComparison.Ordinal)),
                Skipped = skipped
            };
        }

        // 2026-08-29 slice 5. Plain composable SELECT -> SqlQueryRaw on an unmapped type is safe here
        // (no EXEC). Not added to SalesList or any FromSqlRaw entity (plan R3).
        public SalesRepriceStatus GetRepriceStatus()
        {
            return DbContext.Database
                .SqlQueryRaw<SalesRepriceStatus>(
                    """
                    SELECT
                        (SELECT COUNT(*) FROM dbo.Sales WHERE IsPricePending = 1) AS PendingOrderCount,
                        r.RepriceId    AS LastRepriceId,
                        r.RunAt        AS LastRunAt,
                        r.TriggeredBy  AS LastTriggeredBy,
                        r.OrderCount   AS LastOrderCount,
                        r.LineCount    AS LastLineCount,
                        r.SkippedCount AS LastSkippedCount,
                        r.ErrorCount   AS LastErrorCount
                    FROM (SELECT 1 AS One) x
                    LEFT JOIN (SELECT TOP (1) * FROM dbo.SalesReprice ORDER BY RepriceId DESC) r ON 1 = 1
                    """)
                .AsEnumerable()
                .First();
        }

        private static SqlParameter OutInt(string name) => new SqlParameter
        {
            ParameterName = name,
            Direction = ParameterDirection.Output,
            SqlDbType = SqlDbType.Int
        };

        /// <summary>
        /// The procs reject bad input and guard violations with THROW 51xxx and a
        /// plain-English message meant for the user. ExceptionMiddleware maps
        /// SqlException to 500; re-raise those as InvalidOperationException so
        /// they reach the screen as 400 with the message intact. Anything else
        /// (real SQL faults) passes through untouched.
        /// </summary>
        private static T Translate<T>(Func<T> action)
        {
            try
            {
                return action();
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                throw new InvalidOperationException(ex.Message, ex);
            }
        }
    }
}
