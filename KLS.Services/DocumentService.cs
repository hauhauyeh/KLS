using IronPdf;
using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Hosting;
using Omu.ValueInjecter;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class DocumentService : BaseService, IDocumentService
    {
        private readonly IPDFService _pdfService;
        private readonly IPrintLogService _printLogService;
        private readonly IReportService _reportService;
        private readonly ISystemSettingService _systemSettingService;
        private readonly IWebHostEnvironment _env;

        public DocumentService(IUnitOfWork uow,
            IPDFService pdfService,
            IPrintLogService printLogService,
            IReportService reportService,
            ISystemSettingService systemSettingService,
            IWebHostEnvironment env) : base(uow)
        {
            _pdfService = pdfService;
            _printLogService = printLogService;
            _reportService = reportService;
            _systemSettingService = systemSettingService;
            _env = env;
        }

        public string SalesOrder(DocumentReq req)
        {
            if (req?.SalesId is null)
                throw new ArgumentException("SalesId is required.", nameof(req));

            var invoice = _reportService.Invoice(req.SalesId.Value);

            var template = "~/Views/Pdf/SalesOrder.cshtml";
            var html = _pdfService.RenderTemplate(template, invoice);

            var fileName = (invoice.Invoice.SalesTotal < 0 ? "CreditMemo-" : "SalesOrder-") + invoice.Invoice.SalesNumber + ".pdf";
            string filePath = Path.Combine(_env.WebRootPath, "Pdf", fileName);

            using (var pdf = _pdfService.HtmlToPDF(html))
            {
                pdf.SaveAs(filePath);
            }

            return filePath;
        }

        public string PickTicket(DocumentReq req)
        {
            if (req?.SalesId is null)
                throw new ArgumentException("SalesId is required.", nameof(req));

            if (req.IsPrint)
            {
                Uow.Sales.UpdateStage(req.SalesId.Value, 2);
            }

            var invoice = _reportService.Invoice(req.SalesId.Value);

            var template = "~/Views/Pdf/PickTicket.cshtml";
            var documentFormat = _systemSettingService.GetByKey<Int32>(GlobalKey.DOCUMENT_FORMAT);
            if (documentFormat == 3)
                template = "~/Views/Pdf/PickTicket-3.cshtml";

            var html = _pdfService.RenderTemplate(template, invoice);

            var fileName = "PickTicket-" + invoice.Invoice.SalesNumber + ".pdf";
            string filePath = Path.Combine(_env.WebRootPath, "Pdf", fileName);

            using var pdf = _pdfService.HtmlToPDF(html);
            pdf.SaveAs(filePath);

            if (req.IsPrint)
            {
                _printLogService.Create(new PrintLog
                {
                    DocType = "PickTicket-Single",
                    PrintMode = "S",
                    DocPath = filePath,
                    PageCount = pdf.PageCount,
                });
            }

            return filePath;
        }

        public string Invoice(DocumentReq req)
        {
            List<PdfDocument> pdfs = [];
            List<PrintLog> logs = [];

            try
            {
                if (req.SalesId.HasValue)
                {
                    var pdfResult = GenerateInvoice(req.SalesId.Value, req.IsPrint);
                    pdfs.Add(pdfResult.Pdf);

                    logs.Add(new PrintLog
                    {
                        DocType = "Invoice-Single",
                        PrintMode = "S",
                        PageCount = pdfResult.Pdf.PageCount,
                        IsInvoice = true,
                        DocPath = pdfResult.RelativePath,
                        IsBOL = pdfResult.IsBOL
                    });
                }
                else
                {
                    var salesDateRouteReq = new SalesDateRouteReq();
                    salesDateRouteReq.InjectFrom(req);

                    var shipRoutes = Uow.Sales.GetByDateRoute(salesDateRouteReq);

                    foreach (var sales in shipRoutes)
                    {
                        var pdfResult = GenerateInvoice(sales.SalesId, req.IsPrint);
                        pdfs.Add(pdfResult.Pdf);

                        logs.Add(new PrintLog
                        {
                            DocType = "Invoice-Single",
                            PrintMode = "S",
                            PageCount = pdfResult.Pdf.PageCount,
                            IsInvoice = true,
                            DocPath = pdfResult.RelativePath,
                            IsBOL = pdfResult.IsBOL
                        });
                    }
                }

                if (req.IsPrint && logs.Count > 0)
                    _printLogService.CreateBatch(logs);

                //only for view 
                using var merged = PdfDocument.Merge(pdfs);

                var suffix = req.SalesId.HasValue ? req.SalesNumber.ToString()
                    : $"{req.ShipDate:MMddyyyy}-{req.ShipRoute}";
                var fileName = $"Invoice-{suffix}.pdf";
                var filePath = Path.Combine(_env.WebRootPath, "Pdf", fileName);

                if (req.ShipDate.HasValue)
                    merged.SaveAs(filePath);

                return filePath;
            }
            finally
            {
                // IMPORTANT: dispose everything you created and stored in the list
                foreach (var p in pdfs)
                {
                    p?.Dispose();
                }
            }
        }

        public string PackingList(DocumentReq req)
        {
            if (!req.SalesId.HasValue && !req.ShipDate.HasValue)
                throw new ArgumentException("ShipDate is required when SalesId is not provided.", nameof(req));

            var packing = _reportService.PackingList(req);

            var template = "~/Views/Pdf/PackingList.cshtml";
            var html = _pdfService.RenderTemplate(template, packing);

            var suffix = req.SalesId.HasValue ? req.SalesNumber.ToString()
                   : $"{req.ShipDate:MMddyyyy}-{req.ShipRoute}";

            var fileName = $"PackingList-{suffix}.pdf";
            var filePath = Path.Combine(_env.WebRootPath, "Pdf", fileName);

            using var pdf = _pdfService.HtmlToPDF(html);
            pdf.SaveAs(filePath);

            if (req.IsPrint)
            {
                _printLogService.Create(new PrintLog
                {
                    DocType = req.SalesId.HasValue ? "PackingList-Single" : "PackingList-ByRoute",
                    PrintMode = req.SalesId.HasValue ? "S" : "B",
                    DocPath = filePath,
                    PageCount = pdf.PageCount,
                });
            }

            return filePath;
        }

        private PdfGenerationResult GenerateInvoice(int salesId, bool isPrint)
        {
            List<PdfDocument> pdfs = new();
            bool isBOL = false;

            try
            {
                if (isPrint)
                {
                    Uow.Sales.UpdateStage(salesId, 3);
                }

                var invoice = _reportService.Invoice(salesId);

                var documentFormat = _systemSettingService.GetByKey<int>(GlobalKey.DOCUMENT_FORMAT);
                var template = documentFormat switch
                {
                    2 => "~/Views/Pdf/Invoice-2.cshtml",
                    3 => "~/Views/Pdf/Invoice-3.cshtml",
                    _ => "~/Views/Pdf/Invoice.cshtml"
                };

                var html = _pdfService.RenderTemplate(template, invoice);
                var pdf = _pdfService.HtmlToPDF(html);
                pdfs.Add(pdf);

                if (invoice.Invoice.ShippingCarrierId.HasValue)
                {
                    template = "~/Views/Pdf/BOL.cshtml";
                    html = _pdfService.RenderTemplate(template, invoice);

                    pdfs.Add(_pdfService.HtmlToPDF(html));
                    isBOL = true;
                }

                var singlePdf = PdfDocument.Merge(pdfs);

                var salesNumber = invoice.Invoice.SalesNumber;
                var fileName = $"Invoice-{salesNumber}.pdf";
                var relativePath = Path.Combine("Pdf", fileName); // store this in DB
                var fullPath = Path.Combine(_env.WebRootPath, relativePath);

                Directory.CreateDirectory(Path.GetDirectoryName(fullPath)!);

                singlePdf.MetaData.CustomProperties["IsBOL"] = isBOL.ToString();
                singlePdf.SaveAs(fullPath);

                return new PdfGenerationResult
                {
                    Pdf = singlePdf,
                    RelativePath = relativePath,
                    IsBOL = isBOL
                };
            }
            finally
            {
                // Dispose all intermediate PDFs (invoice part + bol part)
                foreach (var p in pdfs)
                {
                    p?.Dispose();
                }
            }
        }
    }
}
