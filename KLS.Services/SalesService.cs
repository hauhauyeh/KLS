using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class SalesService : BaseService, ISalesService
    {
        public SalesService(IUnitOfWork uow) : base(uow)
        {

        }

        public PagingResponse<SalesList> GetPagedList(SalesListReq salesListReq)
        {
            var sales = Uow.Sales.GetPagedList(salesListReq);

            var totalRecords = Uow.Sales.Count(salesListReq);

            // Get absolute path to wwwroot/InvoicePdf
            var invoicePDfPath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "InvoicePdf");

            foreach (var invoice in sales)
            {
                var filePath = Path.Combine(invoicePDfPath, invoice.SalesNumber + ".pdf");

                invoice.IsPdfExist = File.Exists(filePath);
            }

            return new PagingResponse<SalesList>(totalRecords, salesListReq.Pageno, salesListReq.Pagesize)
            {
                RowData = sales,
            };
        }

        public Sales GetById(int salesId)
        {
            return Uow.Sales.GetById(salesId);
        }

        public SalesList? GetListById(int salesId)
        {
            var listReq = new SalesListReq
            {
                Id = salesId
            };

            return Uow.Sales.GetPagedList(listReq).AsEnumerable().FirstOrDefault();
        }

        public Sales UpdateShipRoute(int salesId, string? shipRoute)
        {
            var sales = GetById(salesId);

            if (sales != null)
            {
                if (shipRoute?.Length > 1 && shipRoute != "CM")
                {
                    var load = shipRoute.Last();

                    if (Char.IsNumber(load))
                    {
                        sales.IsLoadSeparate = true;
                        string letters = Regex.Replace(shipRoute, @"\d", "");

                        sales.ShipRoute = letters;
                    }
                    else
                        sales.ShipRoute = shipRoute;
                }
                else
                {
                    sales.ShipRoute = shipRoute;
                }

                sales.UpdatedAt = DateTime.UtcNow;

                Uow.Sales.Update(sales);
                Uow.Commit();
            }

            return sales;
        }

        public void UpdateInstruction(int salesId, string? instruction)
        {
            Uow.Sales.Find(c => c.SalesId == salesId).ExecuteUpdate(setters => setters
            .SetProperty(x => x.Instruction, x => instruction)
            .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));
        }

        public void UpdatePO(int salesId, string? custPO)
        {
            Uow.Sales.Find(c => c.SalesId == salesId).ExecuteUpdate(setters => setters
            .SetProperty(x => x.CustPONumber, x => custPO)
            .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));
        }

        public void UpdateLoadSeparate(int salesId)
        {
            Uow.Sales.Find(c => c.SalesId == salesId).ExecuteUpdate(setters => setters
           .SetProperty(x => x.IsLoadSeparate, x => !x.IsLoadSeparate)
           .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));
        }

        public SalesList UpdateCarrier(int salesId, int? shippingCarrierId)
        {
            Uow.Sales.Find(c => c.SalesId == salesId).ExecuteUpdate(setters => setters
           .SetProperty(x => x.ShippingCarrierId, x => shippingCarrierId)
           .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));

            return GetListById(salesId)!;
        }

        public void Delete(int salesId)
        {
            var sales = Uow.Sales.GetById(salesId);

            if (sales != null && !sales.IsLocked)
            {
                Uow.Sales.Find(c => c.SalesId == salesId).ExecuteDelete();
            }
        }

        public ICollection<string?> GetShipRoutes(DateOnly shipDate)
        {
            return Uow.Sales.Find(c => c.ShipDate == shipDate).OrderBy(c => c.ShipRoute).Select(c => c.ShipRoute).Distinct().ToList();
        }

        public void Inject(int salesId)
        {
            Uow.Sales.Inject(salesId);
        }

        public SalesList Checkout(SalesCheckoutReq checkoutReq)
        {
            var salesId = Uow.Sales.Checkout(checkoutReq);

            return GetListById(salesId)!;
        }

        public SalesList UpdatePartially(int salesId)
        {
            Uow.Sales.UpdatePartially(salesId);

            return GetListById(salesId)!;
        }

        public SalesList UpdateNameDate(SalesUpdateReq updateReq)
        {
            Uow.Sales.UpdateNameDate(updateReq);

            return GetListById(updateReq.SalesId)!;
        }
    }
}
