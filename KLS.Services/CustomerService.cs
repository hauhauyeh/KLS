using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Newtonsoft.Json.Linq;
using Omu.ValueInjecter;
using System.Globalization;
using System.Linq;
using System.Text;
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
        private readonly IEmailSettingService _emailSettingService;
        private readonly IExportService _exportService;

        public CustomerService(IUnitOfWork uow,
            ISystemSettingService systemSettingService,
            ITermService termService,
            ICompanyService companyService,
            IItemQuoteService itemQuoteService,
            IPDFService pdfService,
            IEmailService emailService,
            IEmailSettingService emailSettingService,
            IExportService exportService) : base(uow)
        {
            _systemSettingService = systemSettingService;
            _companyService = companyService;
            _termService = termService;
            _itemQuoteService = itemQuoteService;
            _pdfService = pdfService;
            _emailService = emailService;
            _emailSettingService = emailSettingService;
            _exportService = exportService;
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

            var userAccount = Uow.UserAccounts.Find(u => u.PayeeId == payeeId).FirstOrDefault();
            if (userAccount != null)
            {
                dto.Username = userAccount.Username;
                dto.Password = string.IsNullOrEmpty(userAccount.PasswordHash) ? null : Utilities.Decrypt(userAccount.PasswordHash);
            }

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

        public bool NameExists(string? payeeName, int payeeId)
        {
            return Uow.Payees.Exists(p => p.PayeeName.ToLower() == payeeName.ToLower() && p.PayeeId != payeeId && p.PayeeType == EnumHelper.PayeeType.C.ToString());
        }

        public CustomerDto Create(CustomerDto dto)
        {
            var newPayeeId = GetMaxCustomerId();

            var payee = new Payee();
            payee.InjectFrom(dto);
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

            var customer = new Customer();
            customer.InjectFrom(dto);
            customer.PayeeId = newPayeeId;

            customer.SalesRepId = dto.SalesRepId ?? (UserContext.EmpId == 0 ? null : UserContext.EmpId);
            customer.BillId = dto.BillId ?? newPayeeId;

            Uow.Customers.Add(customer);
            SyncDeliverSchedule(newPayeeId, dto);
            SyncUserAccount(newPayeeId, dto);
            Uow.Commit();

            return GetById(newPayeeId);
        }

        public CustomerDto? Update(CustomerDto dto)
        {
            var customer = Uow.Customers.GetById(dto.PayeeId);
            var existingPayee = Uow.Payees.GetById(dto.PayeeId);

            var mapAPIKey = _systemSettingService.GetByKey<string>(GlobalKey.GOOGLEMAPS_APIKEY);
            var latlong = GetMapLatLong(existingPayee.FullAddress, mapAPIKey);
            var distance = GetDistance(dto.FullAddress, mapAPIKey);

            if (customer == null || existingPayee == null)
                return null;

            // --- Update Payee Fields ---
            existingPayee.PayeeName = dto.PayeeName;
            existingPayee.Address = dto.Address;
            existingPayee.GoogleAddress = dto.GoogleAddress;
            existingPayee.GoogleMapLink = dto.GoogleMapLink;
            existingPayee.City = dto.City;
            existingPayee.State = dto.State;
            existingPayee.ZipCode = dto.ZipCode;
            existingPayee.Email = dto.Email;
            existingPayee.EmailInvoice = dto.EmailInvoice;
            existingPayee.EmailStmt = dto.EmailStmt;
            existingPayee.EmailPricesheet = dto.EmailPricesheet;
            existingPayee.EmailACH = dto.EmailACH;
            existingPayee.TermId = dto.TermId;
            existingPayee.IsClosed = dto.IsClosed;
            existingPayee.IsDelinquent = dto.IsDelinquent;
            existingPayee.GracePeriod = dto.GracePeriod;
            existingPayee.StartDate = dto.StartDate;
            existingPayee.Notes = dto.Notes;
            existingPayee.PhoneDesc1 = dto.PhoneDesc1;
            existingPayee.Phone1 = dto.Phone1;
            existingPayee.PhoneDesc2 = dto.PhoneDesc2;
            existingPayee.Phone2 = dto.Phone2;
            existingPayee.PhoneDesc3 = dto.PhoneDesc3;
            existingPayee.Phone3 = dto.Phone3;
            existingPayee.PhoneDesc4 = dto.PhoneDesc4;
            existingPayee.Phone4 = dto.Phone4;
            existingPayee.PhoneDesc5 = dto.PhoneDesc5;
            existingPayee.Phone5 = dto.Phone5;
            existingPayee.PhoneDesc6 = dto.PhoneDesc6;
            existingPayee.Phone6 = dto.Phone6;
            existingPayee.UpdatedAt = DateTime.UtcNow;

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
                customer.SalesRepId = dto.SalesRepId ?? UserContext.EmpId;
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
                customer.IsHRTaxable = dto.IsHRTaxable;
                customer.CreditLimit = dto.CreditLimit;
                customer.MinOrder = dto.MinOrder;
                customer.ShippingCarrierId = dto.ShippingCarrierId;

                Uow.Customers.Update(customer);
            }

            SyncDeliverSchedule(dto.PayeeId, dto);
            SyncUserAccount(dto.PayeeId, dto);
            Uow.Commit();

            return GetById(customer.PayeeId);
        }

        public void Delete(int payeeId)
        {
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

        private void SyncUserAccount(int payeeId, CustomerDto dto)
        {
            var existingUser = Uow.UserAccounts.Find(u => u.PayeeId == payeeId).FirstOrDefault();
            var hasUsername = !string.IsNullOrWhiteSpace(dto.Username);
            var hasPassword = !string.IsNullOrWhiteSpace(dto.Password);

            if (!hasUsername && !hasPassword)
                return;

            if (!hasUsername || !hasPassword)
                throw new ArgumentException("Username and password are both required for web access.");

            if (existingUser != null)
            {
                existingUser.Email = dto.Email ?? string.Empty;
                existingUser.Phone = dto.Phone1;
                existingUser.Username = dto.Username!;
                existingUser.PasswordHash = Utilities.Encrypt(dto.Password!);
                existingUser.Inactive = dto.IsClosed;
                existingUser.UpdatedAt = DateTime.UtcNow;

                Uow.UserAccounts.Update(existingUser);
                return;
            }

            var userAccount = new UserAccount
            {
                RoleId = 1,
                PayeeId = payeeId,
                Email = dto.Email ?? string.Empty,
                Username = dto.Username!,
                Phone = dto.Phone1,
                PasswordHash = Utilities.Encrypt(dto.Password!),
                Inactive = dto.IsClosed
            };

            Uow.UserAccounts.Add(userAccount);
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

            string? toEmails = customer?.EmailPricesheet;

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

            var setting = _emailSettingService.GetSetting();

            Task.Factory.StartNew(() => _emailService.SendEmail(setting, toEmails, subject, mailBody, null), TaskCreationOptions.LongRunning).ContinueWith((t) =>
            {
                var log = new EmailLog
                {
                    PayeeId = customer?.PayeeId,
                    Email = toEmails,
                    SentDate = DateTime.UtcNow,
                    EventType = EnumHelper.EmailLogEvent.PriceSheet.ToString(),
                    ErrorMessage = t.Result,
                    Status = string.IsNullOrEmpty(t.Result)
                };

                Uow.EmailLogs.Add(log);
                Uow.Commit();
            });
        }

        public void EmailStatement(int payeeId)
        {
            var customer = GetById(payeeId);

            string? toEmails = customer?.EmailStmt;

            if (string.IsNullOrEmpty(toEmails))
                throw new Exception("Email address not found");

            var statement = Uow.Reports.CustStmt(payeeId);

            string subject = "A/R Statement";
            string mailBody = _pdfService.RenderTemplate("~/Views/Statement.cshtml", statement);

            var setting = _emailSettingService.GetSetting();

            Task.Factory.StartNew(() => _emailService.SendEmail(setting, toEmails, subject, mailBody, null), TaskCreationOptions.LongRunning).ContinueWith((t) =>
            {
                var log = new EmailLog
                {
                    PayeeId = customer?.PayeeId,
                    Email = toEmails,
                    SentDate = DateTime.UtcNow,
                    EventType = EnumHelper.EmailLogEvent.Statement.ToString(),
                    ErrorMessage = t.Result,
                    Status = string.IsNullOrEmpty(t.Result)
                };

                Uow.EmailLogs.Add(log);
                Uow.Commit();
            });
        }

        public byte[] Export()
        {
            var customers = Uow.Customers.Export();

            return _exportService.ToExcel(customers, "Customer");
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
            var customerDto = new CustomerDto
            {
                PayeeName = registerReq.PayeeName,
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
                IsApproved = false,
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
            EmailSetting setting = _emailSettingService.GetSetting();
            string subject = "Welcome to " + company.CompanyName;

            Task.Factory.StartNew(() => _emailService.SendEmail(setting, registerReq.Email, subject, mailBody, null), TaskCreationOptions.LongRunning)
                .ContinueWith((t) => { });
        }
    }
}
