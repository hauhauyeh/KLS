using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;

namespace KLS.Services
{
    public class SalesQuoteService : BaseService, ISalesQuoteService
    {
        private const int QuoteStatusDraft = 0;
        private const int QuoteStatusSent = 1;
        private const string CustomerUpdatePermission = "Customer.Customer.Update";
        private const string DefaultSalesQuoteType = "NormalSalesQuote";
        private const string DropShipSalesQuoteType = "DropShipSalesQuote";
        private const string PriceProposalType = "PriceProposal";

        private readonly IDocumentService _documentService;
        private readonly IEmailAuditService _emailAuditService;
        private readonly IWebHostEnvironment _env;
        private readonly IHttpContextAccessor _httpContextAccessor;

        public SalesQuoteService(IUnitOfWork uow,
            IDocumentService documentService,
            IEmailAuditService emailAuditService,
            IWebHostEnvironment env,
            IHttpContextAccessor httpContextAccessor) : base(uow)
        {
            _documentService = documentService;
            _emailAuditService = emailAuditService;
            _env = env;
            _httpContextAccessor = httpContextAccessor;
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

        public SalesQuoteEmailContextDto? GetEmailContext(int salesQuoteId)
        {
            var quote = Uow.SalesQuotes.GetById(salesQuoteId);
            if (quote == null) return null;

            var payee = Uow.Payees.GetById(quote.PayeeId);
            if (payee == null) return null;

            return new SalesQuoteEmailContextDto
            {
                SalesQuoteId = quote.SalesQuoteId,
                QuoteNumber = quote.QuoteNumber,
                PayeeId = quote.PayeeId,
                PayeeName = payee.PayeeName,
                Email = payee.Email,
                EmailPricesheet = payee.EmailPricesheet,
                DefaultEmail = FirstEmail(payee.EmailPricesheet, payee.Email),
                CanSaveToEmailPricesheet = HasPermission(CustomerUpdatePermission)
            };
        }

        public int Insert(int salesQuoteId, int payeeId, DateOnly? expiryDate, string? notes, int statusId, string? salesQuoteType)
        {
            return Uow.SalesQuotes.Insert(salesQuoteId, payeeId, expiryDate, notes, statusId, NormalizeSalesQuoteType(salesQuoteType));
        }

        public void Update(int salesQuoteId, int payeeId, DateOnly? expiryDate, string? notes, string? salesQuoteType)
        {
            Uow.SalesQuotes.Update(salesQuoteId, payeeId, expiryDate, notes, NormalizeSalesQuoteType(salesQuoteType));
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

        public void EmailPdf(int salesQuoteId, SalesQuoteEmailPdfReq? req)
        {
            var quote = GetById(salesQuoteId);
            if (quote == null)
                throw new KeyNotFoundException("Sales quote not found.");

            var toEmail = req?.Email?.Trim();
            if (string.IsNullOrWhiteSpace(toEmail))
                throw new ArgumentException("Email is required.");

            var payee = Uow.Payees.GetById(quote.PayeeId);
            if (payee == null)
                throw new KeyNotFoundException("Quote customer not found.");

            if (req!.SaveToEmailPricesheet)
                RequirePermission(CustomerUpdatePermission, "Customer update permission is required to save Price Sheet Email.");

            var pdfFile = _documentService.SalesQuote(salesQuoteId);

            if (req.SaveToEmailPricesheet)
            {
                if (payee.EmailPricesheet != toEmail)
                {
                    payee.EmailPricesheet = toEmail;
                    payee.UpdatedAt = DateTime.UtcNow;
                    Uow.Payees.Update(payee);
                    Uow.Commit();
                }
            }

            string subject = "Sales Quote #" + quote.QuoteNumber;
            string mailbody = "Hi " + payee.PayeeName + ",<br/><br/>Please find attached your sales quote #" + quote.QuoteNumber + ".<br/><br/>";
            string[] attcfiles = [pdfFile];

            _emailAuditService.SendAndLog(new EmailAuditMessage
            {
                To = toEmail,
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

            if (quote.StatusId == QuoteStatusDraft)
                Uow.SalesQuotes.UpdateStatus(salesQuoteId, QuoteStatusSent);
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

        private static string NormalizeSalesQuoteType(string? salesQuoteType)
        {
            var normalized = string.IsNullOrWhiteSpace(salesQuoteType)
                ? DefaultSalesQuoteType
                : salesQuoteType.Trim();

            if (string.Equals(normalized, DefaultSalesQuoteType, StringComparison.OrdinalIgnoreCase))
                return DefaultSalesQuoteType;

            if (string.Equals(normalized, DropShipSalesQuoteType, StringComparison.OrdinalIgnoreCase))
                return DropShipSalesQuoteType;

            if (string.Equals(normalized, PriceProposalType, StringComparison.OrdinalIgnoreCase))
                return PriceProposalType;

            throw new ArgumentException("Invalid SalesQuoteType.");
        }

        private bool HasPermission(string permissionKey)
        {
            var httpContext = _httpContextAccessor.HttpContext;

            if (httpContext?.Items["IsAdmin"] is bool isAdmin && isAdmin)
                return true;

            if (httpContext?.Items["PermissionKeys"] is HashSet<string> permissionKeys)
                return permissionKeys.Contains(permissionKey);

            return false;
        }

        private void RequirePermission(string permissionKey, string message)
        {
            if (!HasPermission(permissionKey))
                throw new UnauthorizedAccessException(message);
        }
    }
}
