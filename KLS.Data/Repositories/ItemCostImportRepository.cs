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
