using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface IPDFService
    {
        PdfDocument HtmlToPDF(string html);

        string RenderTemplate(string templatePath, object model);
    }
}
