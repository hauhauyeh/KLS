using IronPdf;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using Razor.Templating.Core;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class PDFService : BaseService, IPDFService
    {
        public PDFService(IUnitOfWork uow) : base(uow)
        {
        }

        public PdfDocument HtmlToPDF(string html)
        {
            var chromePdf = new ChromePdfRenderer();

            chromePdf.RenderingOptions.PrintHtmlBackgrounds = true;
            chromePdf.RenderingOptions.CssMediaType = IronPdf.Rendering.PdfCssMediaType.Print;
            chromePdf.RenderingOptions.PaperSize = IronPdf.Rendering.PdfPaperSize.Letter;
            chromePdf.RenderingOptions.MarginBottom = 5;
            chromePdf.RenderingOptions.MarginTop = 8;
            chromePdf.RenderingOptions.MarginLeft = 8;
            chromePdf.RenderingOptions.MarginRight = 8;

            var pdf = chromePdf.RenderHtmlAsPdf(html);

            string footerHtml = @"
            <div style='font-size:12px;margin-bottom:5px'>
                <center>{page} of {total-pages}</center>
            </div>";

            var footer = new HtmlHeaderFooter()
            {
                HtmlFragment = footerHtml,
                LoadStylesAndCSSFromMainHtmlDocument = true,
            };

            var allPageIndexes = Enumerable.Range(0, pdf.PageCount);
            pdf.AddHtmlFooters(footer, 1, allPageIndexes);

            return pdf;
        }

        public string RenderTemplate(string templatePath, object model)
        {
            return RazorTemplateEngine.RenderAsync(templatePath, model).Result;
        }
    }
}
