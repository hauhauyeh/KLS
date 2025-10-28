using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
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

        public PagingResponse<SalesList> GetAllSales(SalesListReq salesListReq)
        {
            var sales = Uow.Sales.GetAllSales(salesListReq);

            var totalRecords = Uow.Sales.CountAllSales(salesListReq);

            // Get absolute path to wwwroot/InvoicePdf
            var invoicePDfPath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "BillPdf");

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
            var sales = GetById(salesId);

            if (sales != null)
            {
                sales.Instruction = instruction;
                sales.UpdatedAt = DateTime.UtcNow;

                Uow.Sales.Update(sales);
                Uow.Commit();
            }
        }

        public void UpdatePO(int salesId, string? custPO)
        {
            var sales = GetById(salesId);

            if (sales != null)
            {
                sales.CustomerPONumber = custPO;
                sales.UpdatedAt = DateTime.UtcNow;

                Uow.Sales.Update(sales);
                Uow.Commit();
            }
        }

        public void DeleteSales(int salesId)
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
    }
}
