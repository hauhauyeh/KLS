using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using KLS.Models.Reports;
using Microsoft.AspNetCore.Hosting;
using Newtonsoft.Json.Linq;
using Omu.ValueInjecter;
using System.Globalization;
using System.Linq;
using System.Net;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Web;
using System.Xml;
using Twilio.Jwt.AccessToken;

namespace KLS.Services
{
    public class CustomerService : BaseService, ICustomerService
    {
        private readonly ISystemSettingService _systemSettingService;
        private readonly ICompanyService _companyService;
        private readonly IItemQuoteService _itemQuoteService;
        private readonly ITermService _termService;
        private readonly IPDFService _pdfService;
        private readonly IEmailService _emailService;
        private readonly IEmailAuditService _emailAuditService;
        private readonly IExportService _exportService;
        private readonly IPortalModeService _portalModeService;
        private readonly IWebHostEnvironment _env;
        private readonly IArEmailPaymentInstructionRenderer _arEmailPaymentInstructionRenderer;

        public CustomerService(IUnitOfWork uow,
            ISystemSettingService systemSettingService,
            ITermService termService,
            ICompanyService companyService,
            IItemQuoteService itemQuoteService,
            IPDFService pdfService,
            IEmailService emailService,
            IEmailAuditService emailAuditService,
            IExportService exportService,
            IPortalModeService portalModeService,
            IWebHostEnvironment env,
            IArEmailPaymentInstructionRenderer arEmailPaymentInstructionRenderer) : base(uow)
        {
            _systemSettingService = systemSettingService;
            _companyService = companyService;
            _termService = termService;
            _itemQuoteService = itemQuoteService;
            _pdfService = pdfService;
            _emailService = emailService;
            _emailAuditService = emailAuditService;
            _exportService = exportService;
            _portalModeService = portalModeService;
            _env = env;
            _arEmailPaymentInstructionRenderer = arEmailPaymentInstructionRenderer;
        }

        public PagingResponse<CustomerList> GetPagedList(CustomerListReq customerListReq)
        {
            var customerlist = Uow.Customers.GetPagedList(customerListReq);

            var totalRecords = Uow.Customers.Count(customerListReq);

            return new PagingResponse<CustomerList>(totalRecords, customerListReq.Pageno, customerListReq.Pagesize)
            {
                RowData = customerlist,
            };
        }

        public CustomerDto GetById(int payeeId)
        {
            var payee = Uow.Payees.GetById(payeeId);
            var customer = Uow.Customers.GetById(payeeId);

            var dto = new CustomerDto();

            if (payee == null && customer == null)
            {
                dto.TaxRate = _systemSettingService.GetByKey<decimal>(GlobalKey.SYSTEM_DEFAULT_TAXRATE);
                //dto.OGSort = EnumHelper.OrderGuideSort.Category.ToString();
                dto.StartDate = DateOnly.FromDateTime(DateTime.Now);
                dto.TermId = _termService.GetByName("COD")?.TermId;
                dto.CallSchedule = "123456";
                dto.GracePeriod = 0;
                dto.MinOrder = 500;
                dto.CreditLimit = 0;
                dto.BaseMarkup = 0;
                dto.PriceShow = "Hide";
                dto.IsPromotionEnabled = true;
                dto.IsStatementPrint = true;
                dto.SalesRepId = UserContext.EmpId;

                return dto;
            }

            EnsureVisible(payeeId);

            if (payee != null)
                dto.InjectFrom(payee);

            if (customer != null)
                dto.InjectFrom(customer);

            var deliverSchedule = Uow.DeliverSchedules.GetActiveByPayeeId(payeeId);
            if (deliverSchedule != null)
            {
                dto.AdvancedScheduleType = deliverSchedule.ScheduleType;
                dto.AdvancedStartDate = deliverSchedule.StartDate;
                dto.AdvancedDayOfWeek = deliverSchedule.DayOfWeek;
                dto.AdvancedWeekOfMonth = deliverSchedule.WeekOfMonth;
                dto.AdvancedDayOfMonth = deliverSchedule.DayOfMonth;
            }

            var userAccounts = Uow.UserAccounts.Find(u => u.PayeeId == payeeId).ToList();
            var roles = Uow.UserRoles.GetAll().ToDictionary(r => r.RoleId, r => r.RoleName);
            dto.WebAccounts = userAccounts.Select(u => new UserAccountDto
            {
                UserId = u.UserId,
                Username = u.Username,
                Email = u.Email,
                Phone = u.Phone,
                Inactive = u.Inactive,
                RoleId = u.RoleId,
                RoleName = roles.GetValueOrDefault(u.RoleId, "Unknown")
            }).ToList();

            //salesrep name
            if (dto.SalesRepId.HasValue)
                dto.SalesRepName = Uow.Payees.GetById(dto.SalesRepId.Value)?.PayeeName;

            //term name
            if (dto.TermId.HasValue)
                dto.TermName = _termService.GetById(dto.TermId.Value)?.TermName;

            //share quote name
            if (dto.ShareQuoteId.HasValue)
                dto.ShareQuoteName = Uow.Payees.GetById(dto.ShareQuoteId.Value)?.PayeeName;

            //bill name
            if (dto.BillId.HasValue)
                dto.BillName = Uow.Payees.GetById(dto.BillId.Value)?.PayeeName;

            dto.OwnListCount = _itemQuoteService.OwnCount(payeeId);

            return dto;
        }

        public void EnsureVisible(int payeeId)
        {
            EnsureVisibleCustomer(payeeId);
        }

        public bool NameExists(string? payeeName, int payeeId)
        {
            if (string.IsNullOrWhiteSpace(payeeName))
                return false;

            return Uow.Payees.Exists(p => p.PayeeName.ToLower() == payeeName.ToLower() && p.PayeeId != payeeId && p.PayeeType == EnumHelper.PayeeType.C.ToString());
        }

        public CustomerDto Create(CustomerDto dto)
        {
            var newPayeeId = GetMaxCustomerId();

            var payee = new Payee();
            payee.InjectFrom(dto);
            NormalizePayeeContactFields(payee);
            payee.PayeeId = newPayeeId;
            payee.PayeeType = EnumHelper.PayeeType.C.ToString();

            var mapAPIKey = _systemSettingService.GetByKey<string>(GlobalKey.GOOGLEMAPS_APIKEY);
            var latlong = GetMapLatLong(payee.FullAddress, mapAPIKey);
            var distance = GetDistance(dto.FullAddress, mapAPIKey);

            if (latlong != null)
            {
                payee.GoogleLat = latlong.Latitude;
                payee.GoogleLong = latlong.Longitude;
                payee.GooglePlaceId = latlong.PlaceId;
                payee.FormatAddress = latlong.FormatAddress;
                payee.Distance = distance;
            }

            Uow.Payees.Add(payee);
            Uow.Commit();

            var customer = new Customer();
            customer.InjectFrom(dto);
            customer.PayeeId = newPayeeId;

            customer.SalesRepId = UserContext.IsSalesRole
                ? UserContext.EmpId
                : dto.SalesRepId ?? (UserContext.EmpId == 0 ? null : UserContext.EmpId);
            customer.BillId = dto.BillId ?? newPayeeId;

            Uow.Customers.Add(customer);
            SyncDeliverSchedule(newPayeeId, dto);
            Uow.Commit();

            return GetById(newPayeeId);
        }

        public CustomerDto? Update(CustomerDto dto)
        {
            EnsureVisible(dto.PayeeId);

            var customer = Uow.Customers.GetById(dto.PayeeId);
            var existingPayee = Uow.Payees.GetById(dto.PayeeId);

            if (customer == null || existingPayee == null)
                return null;

            // Keep the Google-selected geocode values unless the user explicitly reselects an address
            // from autocomplete. Manual edits to Address/City/State/ZipCode are allowed for suite/site
            // adjustments and should not silently overwrite GooglePlaceId/lat/long/FormatAddress.
            var mapAPIKey = _systemSettingService.GetByKey<string>(GlobalKey.GOOGLEMAPS_APIKEY);
            var latlong = GetMapLatLong(existingPayee.FullAddress, mapAPIKey);
            var distance = GetDistance(dto.FullAddress, mapAPIKey);

            // --- Update Payee Fields ---
            existingPayee.PayeeName = dto.PayeeName;
            existingPayee.Address = dto.Address;
            existingPayee.GoogleAddress = dto.GoogleAddress;
            existingPayee.GoogleMapLink = dto.GoogleMapLink;
            existingPayee.City = dto.City;
            existingPayee.State = dto.State;
            existingPayee.ZipCode = dto.ZipCode;
            existingPayee.Country = dto.Country;
            existingPayee.AddressLine2 = CleanText(dto.AddressLine2);
            existingPayee.CountryCode = CleanUpperText(dto.CountryCode);
            existingPayee.Continent = CleanText(dto.Continent);
            existingPayee.Province = CleanText(dto.Province);
            existingPayee.PostalCode = CleanText(dto.PostalCode);
            existingPayee.CurrencyCode = CleanUpperText(dto.CurrencyCode);
            existingPayee.Locale = CleanText(dto.Locale);
            existingPayee.Timezone = CleanText(dto.Timezone);
            existingPayee.TaxRegistrationNumber = CleanText(dto.TaxRegistrationNumber);
            existingPayee.Email = CleanText(dto.Email);
            existingPayee.EmailInvoice = CleanText(dto.EmailInvoice);
            existingPayee.EmailStmt = CleanText(dto.EmailStmt);
            existingPayee.EmailPricesheet = CleanText(dto.EmailPricesheet);
            existingPayee.EmailACH = CleanText(dto.EmailACH);
            existingPayee.TermId = dto.TermId;
            existingPayee.IsClosed = dto.IsClosed;
            existingPayee.IsDelinquent = dto.IsDelinquent;
            existingPayee.GracePeriod = dto.GracePeriod;
            existingPayee.StartDate = dto.StartDate;
            existingPayee.Notes = dto.Notes;
            existingPayee.PhoneDesc1 = CleanText(dto.PhoneDesc1);
            existingPayee.Phone1 = CleanText(dto.Phone1);
            existingPayee.PhoneDesc2 = CleanText(dto.PhoneDesc2);
            existingPayee.Phone2 = CleanText(dto.Phone2);
            existingPayee.PhoneDesc3 = CleanText(dto.PhoneDesc3);
            existingPayee.Phone3 = CleanText(dto.Phone3);
            existingPayee.PhoneDesc4 = CleanText(dto.PhoneDesc4);
            existingPayee.Phone4 = CleanText(dto.Phone4);
            existingPayee.PhoneDesc5 = CleanText(dto.PhoneDesc5);
            existingPayee.Phone5 = CleanText(dto.Phone5);
            existingPayee.PhoneDesc6 = CleanText(dto.PhoneDesc6);
            existingPayee.Phone6 = CleanText(dto.Phone6);
            existingPayee.UpdatedAt = DateTime.UtcNow;

            // Disabled: automatic re-geocoding on save can replace a user-confirmed Google selection
            // after small manual address edits such as suite or site numbers.
            if (latlong != null)
            {
                existingPayee.GoogleLat = latlong.Latitude;
                existingPayee.GoogleLong = latlong.Longitude;
                existingPayee.GooglePlaceId = latlong.PlaceId;
                existingPayee.FormatAddress = latlong.FormatAddress;
                existingPayee.Distance = distance;
            }

            Uow.Payees.Update(existingPayee);

            // --- Update Customer Fields ---

            if (customer != null)
            {
                customer.SalesRepId = UserContext.IsSalesRole ? UserContext.EmpId : dto.SalesRepId ?? UserContext.EmpId;
                customer.BillId = dto.BillId ?? customer.PayeeId;

                customer.Region = dto.Region;
                customer.DefaultRoute = dto.DefaultRoute;
                customer.TextOrderConfirm = dto.TextOrderConfirm;
                customer.TextInvoice = dto.TextInvoice;
                customer.TextStatement = dto.TextStatement;
                customer.TextPricesheet = dto.TextPricesheet;
                customer.TextACH = dto.TextACH;
                customer.OGSort = dto.OGSort;
                customer.IsAutoPayment = dto.IsAutoPayment;
                customer.ShareQuoteId = dto.ShareQuoteId;
                customer.IsShareBasePrice = dto.IsShareBasePrice;
                customer.CallSchedule = dto.CallSchedule;
                customer.IsApproved = dto.IsApproved;
                customer.IsStatementPrint = dto.IsStatementPrint;
                customer.IsStatementEmail = dto.IsStatementEmail;
                customer.IsPriceEmail = dto.IsPriceEmail;
                customer.IsInvoiceEmail = dto.IsInvoiceEmail;
                customer.IsEditGuide = dto.IsEditGuide;
                customer.IsOrderingEnabled = dto.IsOrderingEnabled;
                customer.IsInvoiceEmail = dto.IsInvoiceEmail;
                customer.IsLinkOwnShared = dto.IsLinkOwnShared;
                customer.PriceShow = dto.PriceShow;
                customer.IsPromotionEnabled = dto.IsPromotionEnabled;
                customer.BaseMarkup = dto.BaseMarkup;
                customer.TaxRate = dto.TaxRate;
                customer.RCExpireDate = dto.RCExpireDate;
                customer.RCNumber = dto.RCNumber;
                // 2026-05-16 sales-tax-cleanup
                // customer.IsHRTaxable = dto.IsHRTaxable;
                customer.NonHR = dto.NonHR;
                customer.IsTaxExempt = dto.IsTaxExempt;
                customer.CreditLimit = dto.CreditLimit;
                customer.MinOrder = dto.MinOrder;
                customer.ShippingCarrierId = dto.ShippingCarrierId;

                Uow.Customers.Update(customer);
            }

            SyncDeliverSchedule(dto.PayeeId, dto);
            Uow.Commit();

            return GetById(customer.PayeeId);
        }

        public void Delete(int payeeId)
        {
            EnsureVisible(payeeId);

            Uow.ExecuteInTransaction(() =>
            {
                var existingSchedules = Uow.DeliverSchedules.GetByPayeeId(payeeId).ToList();
                foreach (var existing in existingSchedules)
                {
                    Uow.DeliverSchedules.Remove(existing);
                }

                if (existingSchedules.Count > 0)
                {
                    Uow.Commit();
                }

                Uow.Payees.Delete(payeeId);
            });
        }

        private void SyncDeliverSchedule(int payeeId, CustomerDto dto)
        {
            var activeSchedule = Uow.DeliverSchedules.GetActiveByPayeeId(payeeId);
            if (activeSchedule != null)
            {
                Uow.DeliverSchedules.Remove(activeSchedule);
            }

            if (!HasAdvancedSchedule(dto))
                return;

            var deliverSchedule = new DeliverSchedule
            {
                PayeeId = payeeId,
                ScheduleType = dto.AdvancedScheduleType!,
                StartDate = dto.AdvancedStartDate,
                EndDate = null,
                WeekInterval = dto.AdvancedScheduleType == "BiWeekly" ? 2 : null,
                DayOfWeek = dto.AdvancedDayOfWeek,
                WeekOfMonth = dto.AdvancedScheduleType == "Monthly" ? dto.AdvancedWeekOfMonth : null,
                DayOfMonth = dto.AdvancedScheduleType == "Monthly" ? dto.AdvancedDayOfMonth : null,
                IsActive = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                EnterBy = UserContext.SystemUserId == 0 ? null : UserContext.SystemUserId.ToString(),
                UpdateBy = UserContext.SystemUserId == 0 ? null : UserContext.SystemUserId.ToString()
            };

            Uow.DeliverSchedules.Add(deliverSchedule);
        }

        private static bool HasAdvancedSchedule(CustomerDto dto)
        {
            if (string.IsNullOrWhiteSpace(dto.AdvancedScheduleType))
                return false;

            if (dto.AdvancedScheduleType == "BiWeekly")
                return dto.AdvancedStartDate.HasValue && dto.AdvancedDayOfWeek.HasValue;

            if (dto.AdvancedScheduleType == "Monthly")
                return dto.AdvancedDayOfMonth.HasValue || (dto.AdvancedWeekOfMonth.HasValue && dto.AdvancedDayOfWeek.HasValue);

            return false;
        }

        private static void NormalizePayeeContactFields(Payee payee)
        {
            payee.Email = CleanText(payee.Email);
            payee.EmailInvoice = CleanText(payee.EmailInvoice);
            payee.EmailStmt = CleanText(payee.EmailStmt);
            payee.EmailPricesheet = CleanText(payee.EmailPricesheet);
            payee.EmailACH = CleanText(payee.EmailACH);
            payee.AddressLine2 = CleanText(payee.AddressLine2);
            payee.CountryCode = CleanUpperText(payee.CountryCode);
            payee.Continent = CleanText(payee.Continent);
            payee.Province = CleanText(payee.Province);
            payee.PostalCode = CleanText(payee.PostalCode);
            payee.CurrencyCode = CleanUpperText(payee.CurrencyCode);
            payee.Locale = CleanText(payee.Locale);
            payee.Timezone = CleanText(payee.Timezone);
            payee.TaxRegistrationNumber = CleanText(payee.TaxRegistrationNumber);
            payee.PhoneDesc1 = CleanText(payee.PhoneDesc1);
            payee.Phone1 = CleanText(payee.Phone1);
            payee.PhoneDesc2 = CleanText(payee.PhoneDesc2);
            payee.Phone2 = CleanText(payee.Phone2);
            payee.PhoneDesc3 = CleanText(payee.PhoneDesc3);
            payee.Phone3 = CleanText(payee.Phone3);
            payee.PhoneDesc4 = CleanText(payee.PhoneDesc4);
            payee.Phone4 = CleanText(payee.Phone4);
            payee.PhoneDesc5 = CleanText(payee.PhoneDesc5);
            payee.Phone5 = CleanText(payee.Phone5);
            payee.PhoneDesc6 = CleanText(payee.PhoneDesc6);
            payee.Phone6 = CleanText(payee.Phone6);
        }

        private static string? CleanText(string? value)
        {
            var text = value?.Trim();
            return string.IsNullOrWhiteSpace(text) ? null : text;
        }

        private static string? CleanUpperText(string? value)
        {
            return CleanText(value)?.ToUpperInvariant();
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

        public int GetMaxCustomerId()
        {
            var maxId = Uow.Customers.GetAll().Select(p => (int?)p.PayeeId).Max();
            return (maxId ?? 300000) + 1;
        }

        public ICollection<PayeeSearch>? Search(PayeeSearchReq searchReq)
        {
            return Uow.Customers.Search(searchReq)?.ToList();
        }

        public void EmailPricesheet(int payeeId)
        {
            var customer = GetById(payeeId);

            string? toEmails = FirstEmail(customer?.EmailPricesheet, customer?.Email);

            if (string.IsNullOrEmpty(toEmails))
                throw new Exception("Email address not found");

            var pricesheets = Uow.Reports.Pricesheet(payeeId).ToList();

            if (pricesheets.Count == 0)
                throw new Exception("Pricesheet not found");

            var pricesheet = new EmailPricesheet
            {
                Pricesheet = pricesheets,
                PayeeName = customer?.PayeeName,
                Company = _companyService.GetDefault()
            };

            string subject = "Pricesheet";
            string mailBody = _pdfService.RenderTemplate("~/Views/Pricesheet.cshtml", pricesheet);

            _emailAuditService.SendAndLog(new EmailAuditMessage
            {
                To = toEmails,
                Subject = subject,
                HtmlBody = mailBody,
                EmailCategory = EmailAudit.Category.Document,
                EmailType = EmailAudit.EmailType.PriceSheet,
                PayeeId = customer?.PayeeId,
                DocumentType = EmailAudit.DocumentType.PriceSheet,
                RelatedEntityType = EmailAudit.RelatedEntity.Payee,
                RelatedEntityId = customer?.PayeeId,
                Source = EmailAudit.Source.Manual,
                RequestedBy = UserContext.SystemUserId
            });
        }

        public CustomerStatementEmailResult EmailStatement(int payeeId, CustomerStatementEmailReq? req = null)
        {
            var customer = GetById(payeeId);

            string? toEmails = FirstEmail(req?.RecipientEmail, customer?.EmailStmt, customer?.EmailInvoice, customer?.Email);

            if (string.IsNullOrEmpty(toEmails))
            {
                return new CustomerStatementEmailResult
                {
                    Sent = false,
                    DeliveryStatus = EmailAudit.DeliveryStatus.Failed,
                    Message = "Statement email failed. Customer email address not found.",
                    RecipientEmail = null,
                    AttachmentCount = 0,
                    Error = "Customer email address not found."
                };
            }

            var statement = Uow.Reports.CustStmt(payeeId, req?.Scope ?? StatementScope.ShipTo);
            statement.UseSalesDocNumber = _systemSettingService.GetByKey<bool>(GlobalKey.SALES_DOC_NUMBER_DISPLAY_ENABLED);
            var company = _companyService.GetDefault();
            var totalDue = CalculateStatementTotalDue(statement);
            var tempFolder = CreateEmailAttachmentFolder();

            try
            {
                var attachments = BuildStatementEmailAttachments(tempFolder, statement, customer, payeeId);
                var subject = BuildStatementEmailSubject(company, statement);
                var mailBody = BuildStatementEmailBody(totalDue, company, statement);

                var error = _emailAuditService.SendAndLogSync(new EmailAuditMessage
                {
                    To = toEmails,
                    Subject = subject,
                    HtmlBody = mailBody,
                    Attachments = attachments,
                    EmailCategory = EmailAudit.Category.Document,
                    EmailType = EmailAudit.EmailType.Statement,
                    PayeeId = customer?.PayeeId,
                    DocumentType = EmailAudit.DocumentType.Statement,
                    RelatedEntityType = EmailAudit.RelatedEntity.Payee,
                    RelatedEntityId = customer?.PayeeId,
                    Source = EmailAudit.Source.Manual,
                    RequestedBy = UserContext.SystemUserId
                });

                var sent = string.IsNullOrEmpty(error);

                return new CustomerStatementEmailResult
                {
                    Sent = sent,
                    DeliveryStatus = sent ? EmailAudit.DeliveryStatus.Sent : EmailAudit.DeliveryStatus.Failed,
                    Message = sent
                        ? "Statement email sent."
                        : "Statement email failed.",
                    RecipientEmail = toEmails,
                    AttachmentCount = attachments.Length,
                    Error = sent ? null : error
                };
            }
            finally
            {
                DeleteEmailAttachmentFolder(tempFolder);
            }
        }

        private string[] BuildStatementEmailAttachments(string tempFolder, RptCustStmt statement, CustomerDto? customer, int payeeId)
        {
            var statementHtml = _pdfService.RenderTemplate("~/Views/Statement.cshtml", statement);
            var customerFilePart = SafeFilePart(customer?.PayeeName ?? payeeId.ToString());
            var statementPrefix = IsBillToStatement(statement) ? "BillToStatement" : "Statement";
            var statementFile = Path.Combine(tempFolder, $"{statementPrefix}_{customerFilePart}_{DateTime.Today:yyyyMMdd}.pdf");

            using (var pdf = _pdfService.HtmlToPDF(statementHtml))
            {
                pdf.SaveAs(statementFile);
            }

            if (!File.Exists(statementFile))
                throw new FileNotFoundException("Generated statement PDF was not found.", statementFile);

            return new[] { statementFile };
        }

        private static decimal CalculateStatementTotalDue(RptCustStmt statement)
        {
            return statement.StatementTotalDue
                ?? statement.Details?.Sum(g => g.Sales?.Sum(s => s.AmountDue) ?? 0m)
                ?? 0m;
        }

        private static string BuildStatementEmailSubject(Company? company, RptCustStmt statement)
        {
            var companyName = CleanEmailText(company?.CompanyName ?? company?.DisplayName) ?? "KLS";
            var statementLabel = IsBillToStatement(statement) ? "Bill-To Statement" : "Statement";

            return $"{statementLabel} from {companyName}";
        }

        private string BuildStatementEmailBody(decimal totalDue, Company? company, RptCustStmt statement)
        {
            var companyName = WebUtility.HtmlEncode(CleanEmailText(company?.CompanyName ?? company?.DisplayName) ?? "KLS");
            var companyPhone = WebUtility.HtmlEncode(CleanEmailText(company?.Phone ?? company?.SupportPhone) ?? "");
            var statementLabel = IsBillToStatement(statement) ? "bill-to statement" : "statement";
            var amountDue = WebUtility.HtmlEncode(FormatCurrency(totalDue));
            var paymentBlock = totalDue > 0m ? _arEmailPaymentInstructionRenderer.Render(company) : "";
            var dueSummary = totalDue > 0m
                ? $"""<span style="font-size:14px;color:#333333;">Total Amount Due:</span><br><span style="font-size:30px;font-weight:700;color:#333333;">{amountDue}</span>"""
                : """<span style="display:inline-block;padding:7px 16px;background:#168a4a;color:#ffffff;font-size:20px;font-weight:bold;letter-spacing:1px;border-radius:4px;">NO BALANCE</span>""";
            var bodyMessage = totalDue > 0m
                ? $"Your {statementLabel} with a total amount due of <strong>{amountDue}</strong> is attached."
                : $"Your {statementLabel} is attached for your records. No balance is currently due.";

            return $"""
                <table role="presentation" cellpadding="0" cellspacing="0" style="width:660px;max-width:100%;border-collapse:collapse;border:1px solid #d9deea;font-family:Arial,Helvetica,sans-serif;color:#222222;background:#ffffff;">
                    <tr>
                        <td style="background:#7e8eae;color:#ffffff;padding:11px 28px;font-size:20px;font-weight:600;">
                            {companyName}
                        </td>
                    </tr>
                    <tr>
                        <td style="background:#eef2fa;padding:24px 28px;border-bottom:1px solid #d9deea;">
                            <table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;border-collapse:collapse;">
                                <tr>
                                    <td style="font-size:24px;font-weight:700;color:#333333;">Statement</td>
                                    <td style="text-align:right;">{dueSummary}</td>
                                </tr>
                            </table>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding:22px 28px;font-size:16px;line-height:1.45;">
                            <p style="margin:0 0 18px 0;">Dear Customer:</p>
                            <p style="margin:0 0 16px 0;">{bodyMessage}</p>
                            <p style="margin:0 0 16px 0;">Please review the attached statement PDF for account details.</p>
                            {paymentBlock}
                            <p style="margin:18px 0 16px 0;">Thank you for your business. We appreciate it very much.</p>
                            <p style="margin:0;">Sincerely,<br>{companyName}{BuildCompanyPhoneLine(companyPhone)}</p>
                        </td>
                    </tr>
                    <tr>
                        <td style="height:28px;background:#22283d;font-size:0;line-height:0;">&nbsp;</td>
                    </tr>
                </table>
            """;
        }

        private static bool IsBillToStatement(RptCustStmt statement)
        {
            return string.Equals(statement.StatementScope, StatementScope.BillTo.ToString(), StringComparison.OrdinalIgnoreCase);
        }

        private string CreateEmailAttachmentFolder()
        {
            var folder = Path.Combine(_env.WebRootPath, "EmailAttachments", Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(folder);

            return folder;
        }

        private static string SafeFilePart(string value)
        {
            var safe = Regex.Replace(value, @"[^\w.-]+", "-").Trim('-');

            return string.IsNullOrWhiteSpace(safe) ? "Statement" : safe;
        }

        private static string FormatCurrency(decimal amount)
        {
            return string.Format("{0:C}", amount);
        }

        private static string? CleanEmailText(string? value)
        {
            var clean = value?.Trim();
            return string.IsNullOrEmpty(clean) ? null : clean;
        }

        private static string BuildCompanyPhoneLine(string companyPhone)
        {
            return string.IsNullOrEmpty(companyPhone) ? "" : "<br>" + companyPhone;
        }

        private static void DeleteEmailAttachmentFolder(string folder)
        {
            try
            {
                if (Directory.Exists(folder))
                    Directory.Delete(folder, true);
            }
            catch
            {
                // Best-effort cleanup only. The email send/log result is already known.
            }
        }

        public byte[] Export()
        {
            var customers = Uow.Customers.Export();

            return _exportService.ToExcel(customers, "Customer");
        }

        /// <summary>
        /// Fills GooglePlaceId / GoogleLat / GoogleLong / FormatAddress / Distance for
        /// customers that do not have them yet -- used after a bulk customer import,
        /// where records are created straight in SQL and never pass through Create().
        /// Safe to re-run: already-geocoded customers are skipped unless
        /// <paramref name="overwriteExisting"/> is set.
        /// </summary>
        public GeocodeBackfillResult GeocodeBackfill(bool overwriteExisting)
        {
            var mapAPIKey = _systemSettingService.GetByKey<string>(GlobalKey.GOOGLEMAPS_APIKEY);

            if (string.IsNullOrWhiteSpace(mapAPIKey))
                throw new Exception("Google Maps API key is not configured (SystemSettings key GOOGLEMAPS_APIKEY).");

            var customerType = EnumHelper.PayeeType.C.ToString();
            var payees = Uow.Payees.Find(p => p.PayeeType == customerType).ToList();

            var result = new GeocodeBackfillResult { Total = payees.Count };

            foreach (var payee in payees)
            {
                if (string.IsNullOrWhiteSpace(payee.FullAddress))
                {
                    result.SkippedNoAddress++;
                    continue;
                }

                if (!overwriteExisting && !string.IsNullOrWhiteSpace(payee.GooglePlaceId))
                {
                    result.SkippedAlreadyGeocoded++;
                    continue;
                }

                var latlong = GetMapLatLong(payee.FullAddress, mapAPIKey);

                if (latlong == null)
                {
                    result.Failed++;
                    result.FailedPayeeIds.Add(payee.PayeeId);
                    continue;
                }

                payee.GoogleLat = latlong.Latitude;
                payee.GoogleLong = latlong.Longitude;
                payee.GooglePlaceId = latlong.PlaceId;
                payee.FormatAddress = latlong.FormatAddress;
                payee.Distance = GetDistance(payee.FullAddress, mapAPIKey);
                payee.UpdatedAt = DateTime.UtcNow;

                Uow.Payees.Update(payee);
                result.Updated++;

                // Commit in batches so a timeout part-way through a long run keeps
                // the work already done -- a re-run then picks up where it stopped.
                if (result.Updated % 25 == 0)
                    Uow.Commit();
            }

            Uow.Commit();

            return result;
        }

        private MapLatLong? GetMapLatLong(string address, string mapsApiKey)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(address) || string.IsNullOrWhiteSpace(mapsApiKey))
                    return null;

                var url =
                    "https://maps.googleapis.com/maps/api/geocode/xml" +
                    "?sensor=false" +
                    "&key=" + Uri.EscapeDataString(mapsApiKey) +
                    "&address=" + Uri.EscapeDataString(address);

                using var httpClient = new HttpClient();
                using var request = new HttpRequestMessage(HttpMethod.Get, url);
                using var response = httpClient.Send(request);

                if (!response.IsSuccessStatusCode)
                    return null;

                var xml = response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
                if (string.IsNullOrWhiteSpace(xml))
                    return null;

                var doc = new XmlDocument();
                doc.LoadXml(xml);

                // Ensure Google returned OK
                var status = doc.SelectSingleNode("/GeocodeResponse/status")?.InnerText;
                if (!string.Equals(status, "OK", StringComparison.OrdinalIgnoreCase))
                    return null;

                var latNode = doc.SelectSingleNode("/GeocodeResponse/result/geometry/location/lat");
                var lngNode = doc.SelectSingleNode("/GeocodeResponse/result/geometry/location/lng");
                var placeIdNode = doc.SelectSingleNode("/GeocodeResponse/result/place_id");
                var formattedAddressNode = doc.SelectSingleNode("/GeocodeResponse/result/formatted_address");

                if (latNode == null || lngNode == null)
                    return null;

                // Normalize decimal formatting
                var lat = double.Parse(latNode.InnerText, CultureInfo.InvariantCulture)
                                .ToString(CultureInfo.InvariantCulture);
                var lng = double.Parse(lngNode.InnerText, CultureInfo.InvariantCulture)
                                .ToString(CultureInfo.InvariantCulture);

                return new MapLatLong
                {
                    Latitude = lat,
                    Longitude = lng,
                    PlaceId = placeIdNode?.InnerText ?? string.Empty,
                    FormatAddress = formattedAddressNode?.InnerText ?? string.Empty
                };
            }
            catch (Exception ex)
            {
                return null;
            }
        }

        private string? GetDistance(string? address, string mapsApiKey)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(mapsApiKey) || string.IsNullOrWhiteSpace(address))
                    return null;

                var company = _companyService.GetDefault();
                var originAddress = company?.FullAddress;

                if (string.IsNullOrWhiteSpace(originAddress))
                    return null;

                var url =
                    "https://maps.googleapis.com/maps/api/distancematrix/json" +
                    "?key=" + Uri.EscapeDataString(mapsApiKey) +
                    "&origins=" + Uri.EscapeDataString(originAddress) +
                    "&destinations=" + Uri.EscapeDataString(address);

                using var httpClient = new HttpClient();
                using var request = new HttpRequestMessage(HttpMethod.Get, url);
                using var response = httpClient.Send(request);

                if (!response.IsSuccessStatusCode)
                    return null;

                var json = response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
                if (string.IsNullOrWhiteSpace(json))
                    return null;

                var root = JObject.Parse(json);

                // API-level status: { "status": "OK" }
                var apiStatus = (string?)root["status"];
                if (!string.Equals(apiStatus, "OK", StringComparison.OrdinalIgnoreCase))
                    return null;

                // Element-level status: rows[0].elements[0].status
                var elementStatus = (string?)root["rows"]?[0]?["elements"]?[0]?["status"];
                if (!string.Equals(elementStatus, "OK", StringComparison.OrdinalIgnoreCase))
                    return null;

                // Distance text: rows[0].elements[0].distance.text
                return (string?)root["rows"]?[0]?["elements"]?[0]?["distance"]?["text"];
            }
            catch (Exception ex)
            {
                return null;
            }
        }


        public DateOnly GetNextShipDate(int payeeId)
        {
            return Uow.Customers.GetNextShipDate(payeeId);
        }

        //---web method
        public void Register(RegisterReq registerReq, string url)
        {
            var isB2C = _portalModeService.IsB2C();
            var payeeName = string.IsNullOrWhiteSpace(registerReq.PayeeName)
                ? registerReq.Username
                : registerReq.PayeeName;

            if (isB2C)
            {
                if (string.IsNullOrWhiteSpace(registerReq.Email))
                    throw new Exception("Email is required.");
                if (string.IsNullOrWhiteSpace(registerReq.Phone))
                    throw new Exception("Phone is required.");
                if (string.IsNullOrWhiteSpace(registerReq.Username))
                    throw new Exception("Username is required.");
                if (string.IsNullOrWhiteSpace(registerReq.Address)
                    || string.IsNullOrWhiteSpace(registerReq.City)
                    || string.IsNullOrWhiteSpace(registerReq.State)
                    || string.IsNullOrWhiteSpace(registerReq.ZipCode))
                    throw new Exception("Shipping address is required.");
            }

            var customerDto = new CustomerDto
            {
                PayeeName = payeeName,
                EIN = registerReq.EIN,
                StoreType = registerReq.StoreType,
                Email = registerReq.Email,
                Phone1 = registerReq.Phone,
                Address = registerReq.Address,
                City = registerReq.City,
                State = registerReq.State,
                ZipCode = registerReq.ZipCode,
                TaxRate = _systemSettingService.GetByKey<decimal>(GlobalKey.SYSTEM_DEFAULT_TAXRATE),
                StartDate = DateOnly.FromDateTime(DateTime.Now),
                TermId = _termService.GetByName("COD")?.TermId,
                CallSchedule = "123456",
                GracePeriod = 0,
                MinOrder = 500,
                CreditLimit = 0,
                BaseMarkup = 0,
                PriceShow = "Hide",
                IsPromotionEnabled = true,
                IsStatementPrint = true,
                SalesRepId = null,
                IsApproved = isB2C,
                IsOnlineRegister = true
            };

            var customer = Create(customerDto);

            var token = TokenHelper.GenerateToken();

            var userAccount = new UserAccount
            {
                RoleId = 1,
                PayeeId = customer.PayeeId,
                Username = registerReq.Username,
                Email = registerReq.Email,
                Phone = registerReq.Phone,
                PasswordHash = Utilities.Encrypt(Utilities.GenerateRandomPassword()),
                EmailVerifyCode = token,
                EmailVerifyExpire = DateTime.UtcNow.AddDays(1),
            };

            Uow.UserAccounts.Add(userAccount);
            Uow.Commit();

            string setPasswordUrl = $"{url}/setpassword/{Uri.EscapeDataString(token)}";

            var model = new WelcomeEmail
            {
                Username = registerReq.Username,
                Email = registerReq.Email,
                LoginUrl = setPasswordUrl
            };

            var company = _companyService.GetDefault();

            string mailBody = _emailService.RenderEmailTemplate("~/Views/Register.cshtml", model);
            string subject = "Welcome to " + company.CompanyName;

            _emailAuditService.SendAndLog(new EmailAuditMessage
            {
                To = registerReq.Email,
                Subject = subject,
                HtmlBody = mailBody,
                EmailCategory = EmailAudit.Category.Account,
                EmailType = EmailAudit.EmailType.CustomerRegistration,
                PayeeId = customer.PayeeId,
                RelatedEntityType = EmailAudit.RelatedEntity.UserAccount,
                RelatedEntityId = userAccount.UserId,
                Source = EmailAudit.Source.System
            });
        }
    }
}
