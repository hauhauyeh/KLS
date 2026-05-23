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
        private readonly IEmailSettingService _emailSettingService;
        private readonly IEmailService _emailService;
        private readonly IWebHostEnvironment _env;

        public SalesQuoteService(IUnitOfWork uow,
            IDocumentService documentService,
            IEmailSettingService emailSettingService,
            IEmailService emailService,
            IWebHostEnvironment env) : base(uow)
        {
            _documentService = documentService;
            _emailSettingService = emailSettingService;
            _emailService = emailService;
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

        public int ConvertToSales(int salesQuoteId)
        {
            Uow.SalesQuotes.ConvertToSales(salesQuoteId);
            return salesQuoteId;
        }

        public void EmailPdf(int salesQuoteId)
        {
            var quote = GetById(salesQuoteId);
            if (quote == null) return;

            var pdfFile = _documentService.SalesQuote(salesQuoteId);
            var payee = Uow.Payees.GetById(quote.PayeeId);

            if (payee != null && !string.IsNullOrEmpty(payee.EmailInvoice))
            {
                string toEmails = payee.EmailInvoice;
                string subject = "Sales Quote #" + quote.QuoteNumber;
                string mailbody = "Hi " + payee.PayeeName + ",<br/><br/>Please find attached your sales quote #" + quote.QuoteNumber + ".<br/><br/>";
                string[] attcfiles = [pdfFile];

                var setting = _emailSettingService.GetSetting();

                Task.Factory.StartNew(() => _emailService.SendEmail(setting, toEmails, subject, mailbody, attcfiles), TaskCreationOptions.LongRunning)
                    .ContinueWith((t) =>
                    {
                        var log = new EmailLog
                        {
                            PayeeId = quote.PayeeId,
                            Email = toEmails,
                            SentDate = DateTime.UtcNow,
                            EventType = EnumHelper.EmailLogEvent.Invoice.ToString(),
                            ErrorMessage = t.Result,
                            Status = string.IsNullOrEmpty(t.Result)
                        };

                        Uow.EmailLogs.Add(log);
                        Uow.Commit();
                    });
            }
        }
    }
}
