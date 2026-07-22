using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Hosting;

namespace KLS.Services
{
    public class SalesQuoteService : BaseService, ISalesQuoteService
    {
        private readonly IDocumentService _documentService;
        private readonly IEmailAuditService _emailAuditService;
        private readonly IWebHostEnvironment _env;

        public SalesQuoteService(IUnitOfWork uow,
            IDocumentService documentService,
            IEmailAuditService emailAuditService,
            IWebHostEnvironment env) : base(uow)
        {
            _documentService = documentService;
            _emailAuditService = emailAuditService;
            _env = env;
        }

        public PagingResponse<SalesQuoteList>? GetPagedList(SalesQuoteListReq req)
        {
            var quotes = Uow.SalesQuotes.GetPagedList(req).ToList();
            var totalRecords = Uow.SalesQuotes.Count(req);

            return new PagingResponse<SalesQuoteList>(totalRecords, req.Pageno, req.Pagesize)
            {
                RowData = quotes,
            };
        }

        public SalesQuote GetById(int salesQuoteId)
        {
            return Uow.SalesQuotes.GetById(salesQuoteId);
        }

        public SalesQuoteDetailDto? GetDetail(int salesQuoteId)
        {
            var quote = Uow.SalesQuotes.GetById(salesQuoteId);
            if (quote == null) return null;

            var details = Uow.SalesQuotes.GetDetails(salesQuoteId);
            var payee = Uow.Payees.GetById(quote.PayeeId);

            return new SalesQuoteDetailDto
            {
                SalesQuote = quote,
                Details = details.ToList(),
                PayeeName = payee?.PayeeName
            };
        }

        public int Insert(int salesQuoteId, int payeeId, DateOnly? expiryDate, string? notes, int statusId)
        {
            return Uow.SalesQuotes.Insert(salesQuoteId, payeeId, expiryDate, notes, statusId);
        }

        public void Update(int salesQuoteId, int payeeId, DateOnly? expiryDate, string? notes)
        {
            Uow.SalesQuotes.Update(salesQuoteId, payeeId, expiryDate, notes);
        }

        public void Inject(int salesQuoteId)
        {
            Uow.SalesQuotes.Inject(salesQuoteId);
        }

        public void Delete(int salesQuoteId)
        {
            Uow.SalesQuotes.Delete(salesQuoteId);
        }

        public void UpdateStatus(int salesQuoteId, int statusId)
        {
            Uow.SalesQuotes.UpdateStatus(salesQuoteId, statusId);
        }

        public SalesQuoteConvertResult ConvertToSales(int salesQuoteId)
        {
            return Uow.SalesQuotes.ConvertToSales(salesQuoteId);
        }

        public void EmailPdf(int salesQuoteId)
        {
            var quote = GetById(salesQuoteId);
            if (quote == null) return;

            var pdfFile = _documentService.SalesQuote(salesQuoteId);
            var payee = Uow.Payees.GetById(quote.PayeeId);

            var toEmails = FirstEmail(payee?.EmailPricesheet, payee?.Email);

            if (payee != null && !string.IsNullOrEmpty(toEmails))
            {
                string subject = "Sales Quote #" + quote.QuoteNumber;
                string mailbody = "Hi " + payee.PayeeName + ",<br/><br/>Please find attached your sales quote #" + quote.QuoteNumber + ".<br/><br/>";
                string[] attcfiles = [pdfFile];

                _emailAuditService.SendAndLog(new EmailAuditMessage
                {
                    To = toEmails,
                    Subject = subject,
                    HtmlBody = mailbody,
                    Attachments = attcfiles,
                    EmailCategory = EmailAudit.Category.Document,
                    EmailType = EmailAudit.EmailType.SalesQuote,
                    PayeeId = quote.PayeeId,
                    DocumentType = EmailAudit.DocumentType.SalesQuote,
                    DocumentId = salesQuoteId,
                    DocumentNumber = quote.QuoteNumber.ToString(),
                    Source = EmailAudit.Source.Manual,
                    RequestedBy = UserContext.SystemUserId
                });
            }
        }

        private static string? FirstEmail(params string?[] emails)
        {
            foreach (var email in emails)
            {
                if (!string.IsNullOrWhiteSpace(email))
                    return email.Trim();
            }

            return null;
        }
    }
}
