using ClosedXML.Excel;
using KLS.Contract.Services;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class ExportService : IExportService
    {
        public byte[] ToExcel<T>(IEnumerable<T> list, string worksheetName)
        {
            using var workbook = new XLWorkbook();
            var ws = workbook.Worksheets.Add(worksheetName);

            ws.Cell(1, 1).InsertTable(list);
            ws.Columns().AdjustToContents();

            using var stream = new MemoryStream();
            workbook.SaveAs(stream);

            return stream.ToArray();
        }
    }
}
