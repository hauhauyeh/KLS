using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.Common;
using System.Linq;

namespace KLS.Data.Repositories
{
    public class OpenBalanceRepository : IOpenBalanceRepository
    {
        private readonly KLSDBContext DbContext;

        public OpenBalanceRepository(KLSDBContext dbContext)
        {
            DbContext = dbContext;
        }

        public List<OpenBalanceCardRow> GetStatus()
        {
            return DbContext.OpenBalanceCardRow
                .FromSqlRaw("[dbo].[OpenBalance_Validate]")
                .ToList();
        }

        public List<OpenBalanceExcelRow> Preview(
            string filePath,
            OpenBalanceSection section,
            out DateTime? downloadedAt,
            out int ignoredRowCount)
        {
            var filePathParam = new SqlParameter("@FilePath", filePath);

            var sectionParam = new SqlParameter("@Section", OpenBalanceSectionInfo.Get(section).Token);

            var downloadedAtParam = new SqlParameter
            {
                ParameterName = "@DownloadedAt",
                Direction = ParameterDirection.Output,
                SqlDbType = SqlDbType.DateTime
            };

            var ignoredRowCountParam = new SqlParameter
            {
                ParameterName = "@IgnoredRowCount",
                Direction = ParameterDirection.Output,
                SqlDbType = SqlDbType.Int
            };

            var rows = ExecuteOpenBalanceRows(
                "dbo.OpenBalance_ImportPreview",
                filePathParam,
                sectionParam,
                downloadedAtParam,
                ignoredRowCountParam);

            downloadedAt = downloadedAtParam.Value is DateTime stamp ? stamp : null;
            ignoredRowCount = Convert.ToInt32(ignoredRowCountParam.Value);

            return rows;
        }

        public (int RowCount, int PriorRowCount) Import(string filePath, OpenBalanceSection section)
        {
            var filePathParam = new SqlParameter("@FilePath", filePath);

            var sectionParam = new SqlParameter("@Section", OpenBalanceSectionInfo.Get(section).Token);

            var rowCountParam = new SqlParameter
            {
                ParameterName = "@RowCount",
                Direction = ParameterDirection.Output,
                SqlDbType = SqlDbType.Int
            };

            var priorRowCountParam = new SqlParameter
            {
                ParameterName = "@PriorRowCount",
                Direction = ParameterDirection.Output,
                SqlDbType = SqlDbType.Int
            };

            DbContext.Database.ExecuteSqlRaw(
                "[dbo].[OpenBalance_Import] @FilePath,@Section,@RowCount OUTPUT,@PriorRowCount OUTPUT",
                filePathParam, sectionParam, rowCountParam, priorRowCountParam);

            return (Convert.ToInt32(rowCountParam.Value), Convert.ToInt32(priorRowCountParam.Value));
        }

        public void Unpost(OpenBalanceSection section)
        {
            var sectionParam = new SqlParameter("@Section", OpenBalanceSectionInfo.Get(section).Token);

            DbContext.Database.ExecuteSqlRaw("[dbo].[OpenBalance_Unpost] @Section", sectionParam);
        }

        public List<OpenBalanceExcelRow> GetSectionRows(OpenBalanceSection section, bool includeMasterList)
        {
            var sectionParam = new SqlParameter("@Section", OpenBalanceSectionInfo.Get(section).Token);

            var includeMasterListParam = new SqlParameter("@IncludeMasterList", includeMasterList);

            return ExecuteOpenBalanceRows(
                "dbo.OpenBalance_GetRows",
                sectionParam,
                includeMasterListParam);
        }

        private List<OpenBalanceExcelRow> ExecuteOpenBalanceRows(string procedureName, params SqlParameter[] parameters)
        {
            var connection = DbContext.Database.GetDbConnection();
            var closeConnection = connection.State != ConnectionState.Open;

            using var command = connection.CreateCommand();
            command.CommandText = procedureName;
            command.CommandType = CommandType.StoredProcedure;

            foreach (var parameter in parameters)
                command.Parameters.Add(parameter);

            if (closeConnection)
                connection.Open();

            try
            {
                using var reader = command.ExecuteReader();
                return ReadOpenBalanceRows(reader);
            }
            finally
            {
                if (closeConnection)
                    connection.Close();
            }
        }

        private static List<OpenBalanceExcelRow> ReadOpenBalanceRows(DbDataReader reader)
        {
            var ordinals = Enumerable.Range(0, reader.FieldCount)
                .ToDictionary(reader.GetName, i => i, StringComparer.OrdinalIgnoreCase);

            var rows = new List<OpenBalanceExcelRow>();

            while (reader.Read())
            {
                rows.Add(new OpenBalanceExcelRow
                {
                    RowNo = GetInt(reader, ordinals, nameof(OpenBalanceExcelRow.RowNo)) ?? 0,
                    Key1 = GetString(reader, ordinals, nameof(OpenBalanceExcelRow.Key1)),
                    Key2 = GetString(reader, ordinals, nameof(OpenBalanceExcelRow.Key2)),
                    DocumentDate = GetDateOnlyString(reader, ordinals, nameof(OpenBalanceExcelRow.DocumentDate)),
                    ResolvedId = GetInt(reader, ordinals, nameof(OpenBalanceExcelRow.ResolvedId)),
                    ResolvedName = GetString(reader, ordinals, nameof(OpenBalanceExcelRow.ResolvedName)),
                    Qty = GetDecimal(reader, ordinals, nameof(OpenBalanceExcelRow.Qty)),
                    Price = GetDecimal(reader, ordinals, nameof(OpenBalanceExcelRow.Price)),
                    Amount = GetDecimal(reader, ordinals, nameof(OpenBalanceExcelRow.Amount)),
                    Notes = GetString(reader, ordinals, nameof(OpenBalanceExcelRow.Notes)),
                    Severity = GetString(reader, ordinals, nameof(OpenBalanceExcelRow.Severity)) ?? OpenBalanceSeverity.OK,
                    Message = GetString(reader, ordinals, nameof(OpenBalanceExcelRow.Message))
                });
            }

            return rows;
        }

        private static string? GetString(DbDataReader reader, IReadOnlyDictionary<string, int> ordinals, string name)
        {
            if (!ordinals.TryGetValue(name, out var ordinal) || reader.IsDBNull(ordinal))
                return null;

            return Convert.ToString(reader.GetValue(ordinal));
        }

        private static int? GetInt(DbDataReader reader, IReadOnlyDictionary<string, int> ordinals, string name)
        {
            if (!ordinals.TryGetValue(name, out var ordinal) || reader.IsDBNull(ordinal))
                return null;

            return Convert.ToInt32(reader.GetValue(ordinal));
        }

        private static decimal? GetDecimal(DbDataReader reader, IReadOnlyDictionary<string, int> ordinals, string name)
        {
            if (!ordinals.TryGetValue(name, out var ordinal) || reader.IsDBNull(ordinal))
                return null;

            return Convert.ToDecimal(reader.GetValue(ordinal));
        }

        /// <summary>
        /// Reads a SQL date column as plain yyyy-MM-dd text.
        ///
        /// Returning a DateTime here would hand the value to DateTimeMiddleware,
        /// which treats every DateTime as UTC and shifts it into the user's
        /// timezone, moving a date-only value onto the previous day for anyone
        /// west of UTC. Document dates carry no time, so they never enter that path.
        /// </summary>
        private static string? GetDateOnlyString(DbDataReader reader, IReadOnlyDictionary<string, int> ordinals, string name)
        {
            if (!ordinals.TryGetValue(name, out var ordinal) || reader.IsDBNull(ordinal))
                return null;

            return Convert.ToDateTime(reader.GetValue(ordinal)).ToString("yyyy-MM-dd");
        }
    }
}
