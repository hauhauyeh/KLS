using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
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
        public CustomerService(IUnitOfWork uow) : base(uow)
        {

        }

        public IEnumerable<Payee> GetAllCustomers()
        {
            return Uow.Payees
                .GetAll().Include(v => v.Customer)
                .OrderByDescending(v => v.PayeeId)
                .ToList();
        }

        public Payee? GetById(int payeeId)
        {
            return Uow.Payees.Find(c => c.PayeeId == payeeId).Include(c => c.Customer).FirstOrDefault();
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

            var mapAPIKey = Uow.SystemSettings.GetBySGKey(GlobalKey.SYS_GOOGLEMAPS_APIKEY);
            var latlong = GetMapLatLong(customer.FullAddress, mapAPIKey);

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
            existingPayee.Email = customerDTO.Email;
            existingPayee.EmailInvoice = customerDTO.EmailInvoice;
            existingPayee.EmailStmt = customerDTO.EmailStmt;
            existingPayee.TermName = customerDTO.TermName;
            existingPayee.IsClosed = customerDTO.IsClosed;
            existingPayee.IsDelinquent = customerDTO.IsDelinquent;
            existingPayee.GracePeriod = customerDTO.GracePeriod;
            existingPayee.StartDate = customerDTO.StartDate;
            existingPayee.Notes = customerDTO.Notes;

            existingPayee.UpdatedAt = DateTime.UtcNow;

            Uow.Payees.Update(existingPayee);

            // --- Update Customer Fields ---

            if (customer != null)
            {
                customer.Region = customer.Region;
                customer.DefRoute = customer.DefRoute;
                customer.TextOrderConfirm = customer.TextOrderConfirm;
                customer.TextInvoice = customer.TextInvoice;
                customer.TextStmt = customer.TextStmt;
                customer.TextPricesheet = customer.TextPricesheet;
                customer.TextACH = customer.TextACH;
                customer.OGSort = customer.OGSort;
                customer.IsAutoPayment = customerDTO.IsAutoPayment;
                customer.SalesRep = customerDTO.SalesRep;
                customer.DefBasePriceId = customerDTO.DefBasePriceId;
                customer.DefQuoteId = customerDTO.DefQuoteId;
                customer.BillId = customerDTO.BillId;
                customer.CallSchedule = customerDTO.CallSchedule;
                customer.IsApproved = customerDTO.IsApproved;
                customer.IsStmtPrint = customerDTO.IsStmtPrint;
                customer.IsStmtEmail = customerDTO.IsStmtEmail;
                customer.IsPriceEmail = customerDTO.IsPriceEmail;
                customer.IsInvoiceEmail = customerDTO.IsInvoiceEmail;
                customer.IsEditGuide = customerDTO.IsEditGuide;
                customer.IsOrderingEnabled = customerDTO.IsOrderingEnabled;
                customer.IsInvoiceEmail = customerDTO.IsInvoiceEmail;
                customer.IsLinkOwnShared = customerDTO.IsLinkOwnShared;
                customer.PriceShow = customerDTO.PriceShow;
                customer.ShowPromotion = customerDTO.ShowPromotion;
                customer.Markup = customerDTO.Markup;
                customer.TaxRate = customerDTO.TaxRate;
                customer.RCExpireDate = customerDTO.RCExpireDate;
                customer.RCNumber = customerDTO.RCNumber;
                customer.HRTaxable = customerDTO.HRTaxable;
                customer.CreditLimit = customerDTO.CreditLimit;
                customer.MinOrder = customerDTO.MinOrder;

                if (latlong != null)
                {
                    customer.Lat1 = customerDTO.Lat1;
                    customer.Long1 = customerDTO.Long1;
                    customer.PlaceId = customerDTO.PlaceId;
                    customer.FormatAddress = customerDTO.FormatAddress;
                    customer.Distance = customerDTO.Distance;

                }

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
            return (maxId ?? 100000) + 1;
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
