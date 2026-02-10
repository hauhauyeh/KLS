using IronPdf;
using IronPdf.Rendering;
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
        private static readonly ChromePdfRenderer _renderer = CreateRenderer();

        public PDFService(IUnitOfWork uow) : base(uow)
        {
        }

        public PdfDocument HtmlToPDF(string html)
        {
            return _renderer.RenderHtmlAsPdf(html);
        }

        public PdfDocument AddPageFooter(PdfDocument pdf)
        {
            if (pdf == null || pdf.PageCount == 0)
                return pdf;

            const string footerHtml = @"
            <div style='font-size:14px;margin-bottom:5px'>
                <center>{page} of {total-pages}</center>
            </div>";

            var footer = new HtmlHeaderFooter
            {
                HtmlFragment = footerHtml,
                LoadStylesAndCSSFromMainHtmlDocument = true
            };

            var pageIndexes = Enumerable.Range(0, pdf.PageCount);
            pdf.AddHtmlFooters(footer, 1, pageIndexes);

            return pdf;
        }

        public string RenderTemplate(string templatePath, object model)
        {
            return RazorTemplateEngine.RenderAsync(templatePath, model).Result;
        }

        private static ChromePdfRenderer CreateRenderer()
        {
            var renderer = new ChromePdfRenderer();
            renderer.RenderingOptions.PrintHtmlBackgrounds = true;
            renderer.RenderingOptions.CssMediaType = PdfCssMediaType.Print;
            renderer.RenderingOptions.PaperSize = PdfPaperSize.Letter;
            renderer.RenderingOptions.MarginBottom = 5;
            renderer.RenderingOptions.MarginTop = 8;
            renderer.RenderingOptions.MarginLeft = 8;
            renderer.RenderingOptions.MarginRight = 8;
            return renderer;
        }
    }
}
