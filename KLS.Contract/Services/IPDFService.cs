using IronPdf;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IPDFService
    {
        PdfDocument HtmlToPDF(string html, bool isLabel = false);

        PdfDocument AddPageFooter(PdfDocument pdf, bool isLabel = false);

        string RenderTemplate(string templatePath, object model);
    }
}
