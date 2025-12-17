using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Omu.ValueInjecter;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Web;
using System.Xml;

namespace KLS.Services
{
    public class CustomerService : BaseService, ICustomerService
    {
        private readonly ISystemSettingService _systemSettingService;

        public CustomerService(IUnitOfWork uow, ISystemSettingService systemSettingService) : base(uow)
        {
            _systemSettingService = systemSettingService;
        }

        public PagingResponse<CustomerList> GetAllCustomers(CustomerListReq customerListReq)
        {
            var customerlist = Uow.Customers.GetAllCustomers(customerListReq);

            var totalRecords = Uow.Customers.CountAllCustomers(customerListReq);

            return new PagingResponse<CustomerList>(totalRecords, customerListReq.Pageno, customerListReq.Pagesize)
            {
                RowData = customerlist,
            };
        }

        public CustomerDTO? GetById(int payeeId)
        {
            var payee = Uow.Payees.GetById(payeeId);
            var customer = Uow.Customers.GetById(payeeId);

            if (payee == null && customer == null)
                return null;

            var customerDTO = new CustomerDTO();

            if (payee != null)
                customerDTO.InjectFrom(payee);

            if (customer != null)
                customerDTO.InjectFrom(customer);

            return customerDTO;
        }

        public bool CustomerExists(CustomerDTO customerDTO)
        {
            return Uow.Payees.Exists(p => p.PayeeName.ToLower() == customerDTO.PayeeName.ToLower() && p.PayeeId != customerDTO.PayeeId && p.PayeeType == EnumHelper.PayeeType.E.ToString());
        }

        public CustomerDTO CreateCustomer(CustomerDTO customerDTO)
        {
            var newPayeeId = GetMaxCustomerId();

            var payee = new Payee();
            payee.InjectFrom(customerDTO);
            payee.PayeeId = newPayeeId;
            payee.PayeeType = EnumHelper.PayeeType.C.ToString();

            Uow.Payees.Add(payee);

            var customer = new Customer();
            customer.InjectFrom(customerDTO);
            customer.PayeeId = newPayeeId;

            Uow.Customers.Add(customer);
            Uow.Commit();

            return customerDTO;
        }

        public CustomerDTO? UpdateCustomer(CustomerDTO customerDTO)
        {
            var customer = Uow.Customers.GetById(customerDTO.PayeeId);
            var existingPayee = Uow.Payees.GetById(customerDTO.PayeeId);

            var mapAPIKey = _systemSettingService.GetByKey<string>(GlobalKey.GOOGLEMAPS_APIKEY);
            var latlong = GetMapLatLong(existingPayee.FullAddress, mapAPIKey);

            if (customer == null || existingPayee == null)
                return null;

            // --- Update Payee Fields ---
            existingPayee.PayeeName = customerDTO.PayeeName;
            existingPayee.Address = customerDTO.Address;
            existingPayee.GoogleAddress = customerDTO.GoogleAddress;
            existingPayee.GoogleMapLink = customerDTO.GoogleMapLink;
            existingPayee.City = customerDTO.City;
            existingPayee.State = customerDTO.State;
            existingPayee.ZipCode = customerDTO.ZipCode;
            existingPayee.Email = customerDTO.Email;
            existingPayee.EmailInvoice = customerDTO.EmailInvoice;
            existingPayee.EmailStmt = customerDTO.EmailStmt;
            existingPayee.TermId = customerDTO.TermId;
            existingPayee.IsClosed = customerDTO.IsClosed;
            existingPayee.IsDelinquent = customerDTO.IsDelinquent;
            existingPayee.GracePeriod = customerDTO.GracePeriod;
            existingPayee.StartDate = customerDTO.StartDate;
            existingPayee.Notes = customerDTO.Notes;
            existingPayee.PhoneDesc1 = customerDTO.PhoneDesc1;
            existingPayee.Phone1 = customerDTO.Phone1;
            existingPayee.PhoneDesc2 = customerDTO.PhoneDesc2;
            existingPayee.Phone2 = customerDTO.Phone2;
            existingPayee.PhoneDesc3 = customerDTO.PhoneDesc3;
            existingPayee.Phone3 = customerDTO.Phone3;
            existingPayee.PhoneDesc4 = customerDTO.PhoneDesc4;
            existingPayee.Phone4 = customerDTO.Phone4;
            existingPayee.PhoneDesc5 = customerDTO.PhoneDesc5;
            existingPayee.Phone5 = customerDTO.Phone5;
            existingPayee.PhoneDesc6 = customerDTO.PhoneDesc6;
            existingPayee.Phone6 = customerDTO.Phone6;


            existingPayee.UpdatedAt = DateTime.UtcNow;

            if (latlong != null)
            {
                existingPayee.GoogleLat = customerDTO.GoogleLat;
                existingPayee.GoogleLong = customerDTO.GoogleLong;
                existingPayee.GooglePlaceId = customerDTO.GooglePlaceId;
                existingPayee.FormatAddress = customerDTO.FormatAddress;
                existingPayee.Distance = customerDTO.Distance;
            }

            Uow.Payees.Update(existingPayee);

            // --- Update Customer Fields ---

            if (customer != null)
            {
                customer.Region = customer.Region;
                customer.DefaultRoute = customer.DefaultRoute;
                customer.TextOrderConfirm = customer.TextOrderConfirm;
                customer.TextInvoice = customer.TextInvoice;
                customer.TextStatement = customer.TextStatement;
                customer.TextPricesheet = customer.TextPricesheet;
                customer.TextACH = customer.TextACH;
                customer.OGSort = customer.OGSort;
                customer.IsAutoPayment = customerDTO.IsAutoPayment;
                customer.SalesRepId = customerDTO.SalesRepId;
                //customer.DefaultBasePriceId = customerDTO.DefaultBasePriceId;
                customer.ShareQuoteId = customerDTO.ShareQuoteId;
                customer.IsShareBasePrice = customerDTO.IsShareBasePrice;
                customer.BillId = customerDTO.BillId;
                customer.CallSchedule = customerDTO.CallSchedule;
                customer.IsApproved = customerDTO.IsApproved;
                customer.IsStatementPrint = customerDTO.IsStatementPrint;
                customer.IsStatementEmail = customerDTO.IsStatementEmail;
                customer.IsPriceEmail = customerDTO.IsPriceEmail;
                customer.IsInvoiceEmail = customerDTO.IsInvoiceEmail;
                customer.IsEditGuide = customerDTO.IsEditGuide;
                customer.IsOrderingEnabled = customerDTO.IsOrderingEnabled;
                customer.IsInvoiceEmail = customerDTO.IsInvoiceEmail;
                customer.IsLinkOwnShared = customerDTO.IsLinkOwnShared;
                customer.PriceShow = customerDTO.PriceShow;
                customer.IsPromotionEnabled = customerDTO.IsPromotionEnabled;
                customer.BaseMarkup = customerDTO.BaseMarkup;
                customer.TaxRate = customerDTO.TaxRate;
                customer.RCExpireDate = customerDTO.RCExpireDate;
                customer.RCNumber = customerDTO.RCNumber;
                customer.IsHRTaxable = customerDTO.IsHRTaxable;
                customer.CreditLimit = customerDTO.CreditLimit;
                customer.MinOrder = customerDTO.MinOrder;

                Uow.Customers.Update(customer);
            }

            Uow.Commit();

            return customerDTO;
        }

        public void DeleteCustomer(int payeeId)
        {
            Uow.Payees.RemoveById(payeeId);
            Uow.Commit();
        }

        public int GetMaxCustomerId()
        {
            var maxId = Uow.Customers.GetAll().Select(p => (int?)p.PayeeId).Max();
            return (maxId ?? 300000) + 1;
        }

        public ICollection<PayeeSearch>? SearchCustomer(PayeeSearchReq searchReq)
        {
            return Uow.Customers.SearchCustomer(searchReq)?.ToList();
        }

        private static MapLatLong? GetMapLatLong(string Address, string MapsAPIKEY)
        {
            try
            {
                if (string.IsNullOrEmpty(MapsAPIKEY))
                    return null;

                string apiurl = "https://maps.googleapis.com/maps/api/geocode/xml?sensor=false&key=" + MapsAPIKEY;
                string param = HttpUtility.UrlEncode(Address);
                apiurl = apiurl + "&address=" + param;

                string jsonData;

                using var httpClient = new HttpClient();
                var request = new HttpRequestMessage(HttpMethod.Get, apiurl);
                var response = httpClient.Send(request);
                using var reader = new StreamReader(response.Content.ReadAsStream());
                jsonData = reader.ReadToEnd();

                XmlDocument doc = new();
                doc.LoadXml(jsonData);

                XmlNodeList parentNode = doc.GetElementsByTagName("location");
                XmlNode? placeIdNode = doc.GetElementsByTagName("place_id")[0];
                XmlNode? addressNode = doc.GetElementsByTagName("formatted_address")[0];
                var lat = "";
                var lng = "";

                foreach (XmlNode childrenNode in parentNode)
                {
                    lat = childrenNode.SelectSingleNode("lat").InnerText;
                    lng = childrenNode.SelectSingleNode("lng").InnerText;
                }

                return new MapLatLong
                {
                    Latitude = Convert.ToString(lat),
                    Longitude = Convert.ToString(lng),
                    PlaceId = Convert.ToString(placeIdNode.InnerText),
                    FormatAddress = Convert.ToString(addressNode.InnerText)
                };
            }
            catch (Exception ex)
            {
                return null;
            }
        }
    }
}
