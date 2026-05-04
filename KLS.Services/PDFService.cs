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
        //private static readonly ChromePdfRenderer _renderer = CreateRenderer();

        public PDFService(IUnitOfWork uow) : base(uow)
        {
        }

        public PdfDocument HtmlToPDF(string html, bool isLabel = false)
        {
            var renderer = CreateRenderer(isLabel);
            return renderer.RenderHtmlAsPdf(html);
        }

        public PdfDocument AddPageFooter(PdfDocument pdf, bool isLabel = false)
        {
            if (isLabel || pdf == null || pdf.PageCount == 0)
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

        //private static ChromePdfRenderer CreateRenderer()
        //{
        //    var renderer = new ChromePdfRenderer();
        //    renderer.RenderingOptions.PrintHtmlBackgrounds = true;
        //    renderer.RenderingOptions.CssMediaType = PdfCssMediaType.Print;
        //    renderer.RenderingOptions.PaperSize = PdfPaperSize.Letter;
        //    renderer.RenderingOptions.MarginBottom = 5;
        //    renderer.RenderingOptions.MarginTop = 8;
        //    renderer.RenderingOptions.MarginLeft = 8;
        //    renderer.RenderingOptions.MarginRight = 8;
        //    return renderer;
        //}

        private static ChromePdfRenderer CreateRenderer(bool isLabel = false)
        {
            var renderer = new ChromePdfRenderer();

            renderer.RenderingOptions.PrintHtmlBackgrounds = true;
            renderer.RenderingOptions.CssMediaType = PdfCssMediaType.Print;

            if (isLabel)
            {
                renderer.RenderingOptions.MarginTop = 0;
                renderer.RenderingOptions.MarginBottom = 0;
                renderer.RenderingOptions.MarginLeft = 5;
                renderer.RenderingOptions.MarginRight = 5;
                renderer.RenderingOptions.PaperSize = PdfPaperSize.Custom;
                renderer.RenderingOptions.SetCustomPaperSizeInInches(4, 6);
            }
            else
            {
                renderer.RenderingOptions.PrintHtmlBackgrounds = true;
                renderer.RenderingOptions.CssMediaType = PdfCssMediaType.Print;
                renderer.RenderingOptions.PaperSize = PdfPaperSize.Letter;
                renderer.RenderingOptions.MarginBottom = 5;
                renderer.RenderingOptions.MarginTop = 8;
                renderer.RenderingOptions.MarginLeft = 8;
                renderer.RenderingOptions.MarginRight = 8;
            }

            return renderer;
        }
    }
}
