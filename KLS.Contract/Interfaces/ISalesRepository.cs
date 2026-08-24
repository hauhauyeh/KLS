using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface ISalesRepository : IRepository<Sales>
    {
        IQueryable<SalesList> GetPagedList(SalesListReq salesListReq);

        int Count(SalesListReq salesListReq);

        void Inject(int salesId);

        int Checkout(SalesCheckoutReq checkoutReq);

        void UpdatePartially(int salesId);

        SalesDropShipRestrictedUpdateResult DropShipRestrictedUpdate(int salesId);

        void UpdateNameDate(SalesUpdateReq updateReq);

        void InsertShippingCharge(SalesUpdateReq updateReq);

        IQueryable<ShipRouteSummary>? ShipRouteSummary(DateOnly shipDate);

        IQueryable<ShipRouteDetail>? ShipRouteDetail(DateOnly shipDate);

        IQueryable<ShipRouteDetail>? GetByDateRoute(DateOnly shipDate, string? shipRoute);

        SalesStage UpdateStage(int salesId, int stageId);

        SalesStage EnterEditMode(int salesId);

        SalesStage RestoreStage(int salesId, int stageId);

        void ClearDropShipOrderDetailQuantities(int salesId);

        void BatchAllocation(DateOnly shipDate);

        void SingleAllocation(int salesId);

        int MergeOrder(SalesMergeReq mergeReq);

        IQueryable<SalesExport>? Export(SalesExportReq exportReq);

        IQueryable<SalesDetailList>? GetSalesDetails(int salesId);

        //--Web
        IQueryable<OrderWebList>? GetWebPagedList(SalesListReq salesListReq);

        int WebOrderCount(SalesListReq salesListReq);
    }
}
