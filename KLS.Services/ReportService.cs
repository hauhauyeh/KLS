using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using KLS.Models.Reports;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class ReportService : BaseService, IReportService
    {
        private readonly ICompanyService _companyService;
        private readonly ISystemSettingService _systemSettingService;
        private readonly ISalesRouteService _salesRouteService;

        public ReportService(IUnitOfWork uow,
            ICompanyService companyService,
            ISystemSettingService systemSettingService,
            ISalesRouteService salesRouteService) : base(uow)
        {
            _companyService = companyService;
            _systemSettingService = systemSettingService;
            _salesRouteService = salesRouteService;
        }

        public RptInvoice Invoice(int salesId)
        {
            var invoice = Uow.Reports.Invoice(salesId);

            return new RptInvoice
            {
                Invoice = Uow.Reports.Invoice(salesId),
                InvoiceDetails = Uow.Reports.InvoiceDetail(salesId)?.ToList(),
                Statement = CustStmt(invoice.ShipId),
                Company = _companyService.GetDefault(),
                HasDiscount = _systemSettingService.GetByKey<Boolean>(GlobalKey.SYSTEM_HAS_DISCOUNT),
                //Promotions = _PromotionManager.GetDisplay(),
            };
        }

        public RptCustStmt CustStmt(int payeeId)
        {
            var details = Uow.Sales.Find(s => s.ShipId == payeeId && s.AmountDue != 0)
                .GroupBy(s => new { s.ShipDate.Value.Year, s.ShipDate.Value.Month })
                .Select(g => new RptCustStmtDetail
                {
                    ShipMonth = new DateTimeFormatInfo().GetMonthName(g.Key.Month) + " - " + g.Key.Year.ToString(),
                    Sales = g.OrderBy(s => s.ShipDate).ToList()
                }).ToList();

            var customer = Uow.Customers.GetById(payeeId);

            return new RptCustStmt
            {
                Details = details,
                Payee = Uow.Payees.GetById(payeeId),
                IsPromotionEnabled = customer.IsPromotionEnabled,
                AvailableCredit = Uow.CustomerPayments.Find(c => c.PayeeId == payeeId && c.UnappliedAmount != 0 && c.IsReturned == false).ToList()
            };
        }

        public RptPackingList PackingList(DocumentReq req)
        {
            var packingItems = Uow.Reports.PackingList(req).ToList();

            var packingStorage = packingItems.GroupBy(c => c.StorageName).Select(g => new PackingListStorage
            {
                StorageName = g.Key,
                WeightTotal = g.Sum(c => c.ItemWeight),
                Products = g.GroupBy(c => new { c.ItemName, c.Comment }).Select(p => new PackingListProduct
                {
                    ItemName = p.Key.ItemName,
                    Comment = p.Key.Comment,
                    Items = p.ToList()
                }).ToList()
            }).ToList();

            var payeeName = "";

            if (req.SalesId.HasValue)
            {
                var sales = Uow.Sales.GetById(req.SalesId.Value);
                payeeName = Uow.Payees.GetById(sales.ShipId.Value)?.PayeeName;
                req.ShipDate = sales.ShipDate;
                req.ShipRoute = sales.ShipRoute;
            }

            return new RptPackingList
            {
                ShipDate = req.ShipDate,
                ShipRoute = req.ShipRoute,
                SalesId = req.SalesId,
                PayeeName = payeeName,
                TruckNumber = _salesRouteService.GetByDateRoute(req.ShipDate, req.ShipRoute)?.TruckNumber,
                Storages = packingStorage
            };
        }
    }
}
