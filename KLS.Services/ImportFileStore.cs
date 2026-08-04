using KLS.Common;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using System;
using System.IO;

namespace KLS.Services
{
    /// <summary>
    /// Holds an uploaded workbook on disk between the preview the user approves
    /// and the import that acts on it, keyed by an opaque token.
    ///
    /// The token is concatenated into a file path AND into an OLEDB connection
    /// string, so anything that is not a GUID is rejected outright.
    ///
    /// Extracted from the PayNow importer, which still carries its own private
    /// copy: switching it over is a refactor of working code and does not
    /// belong in a feature change.
    /// </summary>
    public class ImportFileStore
    {
        private static readonly TimeSpan Retention = TimeSpan.FromHours(24);

        private readonly IWebHostEnvironment _hostingEnvironment;
        private readonly string _subFolder;

        public ImportFileStore(IWebHostEnvironment hostingEnvironment, string subFolder)
        {
            _hostingEnvironment = hostingEnvironment;
            _subFolder = subFolder;
        }

        /// <summary>Saves the upload and returns its token. Sweeps expired files first.</summary>
        public string Save(IFormFile file)
        {
            if (file == null || file.Length == 0)
                throw new ArgumentException("Please upload an Excel file.");

            var extension = Path.GetExtension(file.FileName);

            if (!string.Equals(extension, ".xlsx", StringComparison.OrdinalIgnoreCase))
                throw new ArgumentException("Only .xlsx files can be imported. Save the workbook as .xlsx and try again.");

            var root = Root();

            Directory.CreateDirectory(root);
            SweepExpired(root);

            var token = Guid.NewGuid().ToString("N");

            using (var stream = new FileStream(PathFor(token), FileMode.Create, FileAccess.Write))
            {
                file.CopyTo(stream);
            }

            return token;
        }

        public string PathFor(string? token)
        {
            if (string.IsNullOrWhiteSpace(token) || !Guid.TryParseExact(token, "N", out _))
                throw new ArgumentException("The uploaded file expired. Please upload it again.");

            return Path.Combine(Root(), $"{token}.xlsx");
        }

        public string ExistingPathFor(string? token)
        {
            var path = PathFor(token);

            if (!File.Exists(path))
                throw new ArgumentException("The uploaded file expired. Please upload it again.");

            return path;
        }

        /// <summary>
        /// ACE keeps a handle on the workbook, so a delete can legitimately
        /// fail. The rows are already committed by then; never let cleanup turn
        /// a successful import into an error.
        /// </summary>
        public void TryDelete(string path)
        {
            try
            {
                if (File.Exists(path))
                    File.Delete(path);
            }
            catch
            {
                // Swept later by Save().
            }
        }

        private string Root()
        {
            // Constants.PayrollPath is declared nullable but is set at startup.
            // Fall back rather than risk a null path deep inside a file write.
            var payrollPath = Constants.PayrollPath ?? "Payroll";

            return Path.Combine(_hostingEnvironment.WebRootPath, payrollPath, _subFolder);
        }

        private static void SweepExpired(string root)
        {
            try
            {
                var cutoff = DateTime.UtcNow - Retention;

                foreach (var file in Directory.EnumerateFiles(root, "*.xlsx"))
                {
                    if (File.GetLastWriteTimeUtc(file) < cutoff)
                        File.Delete(file);
                }
            }
            catch
            {
                // Housekeeping must never fail an upload.
            }
        }
    }
}
