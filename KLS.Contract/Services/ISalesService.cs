using KLS.Models;
using System;
using KLS.Models.Reports;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ISalesService
    {
        PagingResponse<SalesList>? GetPagedList(SalesListReq salesListReq);

        Sales GetById(int salesId);

        Sales? GetBySalesNumber(int salesNumber);

        Sales UpdateShipRoute(int salesId, string? shipRoute);

        void UpdateInstruction(int salesId, string? instruction);

        void UpdatePO(int salesId, string? custPO);

        void UpdateLoadSeparate(int salesId);

        SalesList UpdateCarrier(int salesId, int? shippingCarrierId);

        SalesStage UpdateStage(int salesId, int stageId);

        SalesStage EnterEditMode(int salesId);

        SalesStage RestoreStage(int salesId, int stageId);

        void Delete(int salesId);

        ICollection<string?> GetShipRoutes(DateOnly shipDate);

        void Inject(int salesId);

        SalesList Checkout(SalesCheckoutReq checkoutReq);

        SalesList UpdatePartially(int salesId);

        SalesList UpdateNameDate(SalesUpdateReq updateReq);

        SalesList InsertShippingCharge(SalesUpdateReq updateReq);

        bool IsInvoicePdfExist(int salesNumber);

        IEnumerable<ShipRouteDetail>? GetByDateRoute(SalesDateRouteReq dateRouteReq);

        void BatchAllocation(DateOnly shipDate);

        void SingleAllocation(int salesId);

        void EmailPdf(int salesId);

        int MergeOrder(SalesMergeReq mergeReq);

        string MergePdf(string salesNumbers);

        SalesSeePayment SeePayment(int salesId);

        IEnumerable<SalesList>? OpenInvoices(int payeeId);

        IEnumerable<SalesList>? PastDueInvoices(int payeeId);

        IEnumerable<CustBoughtItemPanelRow> CustBoughtItemsPanel(int payeeId);

        byte[] Export(SalesExportReq exportReq);

        SalesDetailDto? GetSalesDetails(int salesId);

        //--Routing

        IEnumerable<ShipRouteSummary>? ShipRouteSummary(DateOnly shipDate);

        void UpdateRouteOrder(List<ShipRouteDetail> routeDetails);

        void UpdateRoute(List<ShipRouteDetail> routeDetails);

        //--Web
        PagingResponse<OrderWebList>? GetWebPagedList(SalesListReq salesListReq);

        int WebCheckout(SalesWebCheckoutReq webCheckoutReq);
    }
}
