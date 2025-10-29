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

        public PagingResponse<CustomerList> GetAllCustomers(CustomerListReq customerListReq)
        {
            var customerlist = Uow.Customers.GetAllCustomers(customerListReq);

            var totalRecords = Uow.Customers.CountAllCustomers(customerListReq);

            return new PagingResponse<CustomerList>(totalRecords, customerListReq.Pageno, customerListReq.Pagesize)
            {
                RowData = customerlist,
            };
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

            //var mapAPIKey = Uow.SystemSettings.GetBySGKey(GlobalKey.SYS_GOOGLEMAPS_APIKEY);
            //var latlong = GetMapLatLong(customer.add, mapAPIKey);

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

            existingPayee.UpdatedAt = DateTime.UtcNow;

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
                customer.SalesRep = customerDTO.SalesRep;
                customer.DefaultBasePriceId = customerDTO.DefaultBasePriceId;
                customer.DefaultQuoteId = customerDTO.DefaultQuoteId;
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

                //if (latlong != null)
                //{
                //    customer.Lat1 = customerDTO.Lat1;
                //    customer.Long1 = customerDTO.Long1;
                //    customer.PlaceId = customerDTO.PlaceId;
                //    customer.FormatAddress = customerDTO.FormatAddress;
                //    customer.Distance = customerDTO.Distance;
                //}

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
