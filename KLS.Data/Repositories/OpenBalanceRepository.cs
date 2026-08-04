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

            // Materialise here. The proc contains INSERT ... EXEC, and SQL Server
            // rejects a SELECT composed over an INSERT-EXEC. Returning IQueryable
            // would let a caller add a .Where()/.OrderBy() that EF turns into a
            // wrapping subquery, breaking the proc at runtime. Returning List<>
            // makes that unreachable.
            var rows = DbContext.OpenBalanceExcelRow
                .FromSqlRaw("[dbo].[OpenBalance_ImportPreview] @FilePath,@Section,@DownloadedAt OUTPUT,@IgnoredRowCount OUTPUT",
                    filePathParam, sectionParam, downloadedAtParam, ignoredRowCountParam)
                .ToList();

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

            return DbContext.OpenBalanceExcelRow
                .FromSqlRaw("[dbo].[OpenBalance_GetRows] @Section,@IncludeMasterList",
                    sectionParam, includeMasterListParam)
                .ToList();
        }
    }
}
