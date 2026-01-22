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

            foreach (var invoice in sales)
            {
                invoice.IsPdfExist = IsInvoicePdfExist(invoice.SalesNumber);
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
                    sales.ShipRoute = string.IsNullOrEmpty(shipRoute) ? null : shipRoute;
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

        public SalesStage UpdateStage(int salesId, int stageId)
        {
            var sales = GetById(salesId);

            if (sales != null)
            {
                var oldStageId = sales.StageId;

                sales.StageId = stageId;
                Uow.Sales.Update(sales);
                Uow.Commit();

                if (oldStageId == 0 && stageId == 2)
                    SingleAllocation(salesId);
            }

            return Uow.SalesStages.GetById(stageId);
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

        public SalesList InsertShippingCharge(SalesUpdateReq updateReq)
        {
            Uow.Sales.InsertShippingCharge(updateReq);

            return GetListById(updateReq.SalesId)!;
        }

        public bool IsInvoicePdfExist(int salesNumber)
        {
            // Get absolute path to wwwroot/InvoicePdf
            var invoicePDfPath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "InvoicePdf");

            var filePath = Path.Combine(invoicePDfPath, salesNumber + ".pdf");

            return File.Exists(filePath);
        }

        public IEnumerable<ShipRouteDetail>? GetByDateRoute(SalesDateRouteReq dateRouteReq)
        {
            return Uow.Sales.GetByDateRoute(dateRouteReq);
        }

        public void BatchAllocation(DateOnly shipDate)
        {
            Uow.Sales.BatchAllocation(shipDate);
        }

        public void SingleAllocation(int salesId)
        {
            Uow.Sales.SingleAllocation(salesId);
        }


        public IEnumerable<ShipRouteSummary>? ShipRouteSummary(DateOnly shipDate)
        {
            var summary = Uow.Sales.ShipRouteSummary(shipDate)?.ToList();

            if (summary == null) return null;

            var routeDetail = Uow.Sales.ShipRouteDetail(shipDate)?.ToList();

            foreach (var s in summary)
            {
                s.ShipRouteDetails = routeDetail?.Where(c => c.ShipRoute == s.ShipRoute).ToList();
            }

            return summary;
        }

        public void UpdateRouteOrder(List<ShipRouteDetail> routeDetails)
        {
            foreach (var route in routeDetails)
            {
                Uow.Sales.Find(c => c.SalesId == route.SalesId).ExecuteUpdate(setters => setters
                .SetProperty(x => x.RouteOrder, x => route.RouteOrder)
                .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));
            }
        }

        public void UpdateRoute(List<ShipRouteDetail> routeDetails)
        {
            foreach (var route in routeDetails)
            {
                Uow.Sales.Find(c => c.SalesId == route.SalesId).ExecuteUpdate(setters => setters
                .SetProperty(x => x.ShipRoute, x => route.ShipRoute)
                .SetProperty(x => x.IsLoadSeparate, x => route.IsLoadSeparate)
                .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));
            }
        }
    }
}
