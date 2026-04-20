using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using KLS.Models.Reports;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class PurchaseOrderService : BaseService, IPurchaseOrderService
    {
        private readonly IDeleteLogService _deleteLogService;
        private readonly ICompanyService _companyService;
        private readonly IPDFService _pdfService;
        private readonly IWebHostEnvironment _env;

        public PurchaseOrderService(IUnitOfWork uow,
            IDeleteLogService deleteLogService,
            ICompanyService companyService,
            IPDFService pdfService, 
            IWebHostEnvironment env) : base(uow)
        {
            _deleteLogService = deleteLogService;
            _companyService = companyService;
            _pdfService = pdfService;
            _env = env;
        }

        public PagingResponse<POList> GetPagedList(POListReq purchaseOrderReq)
        {
            var list = Uow.PurchaseOrders.GetPagedList(purchaseOrderReq);

            var totalRecords = Uow.PurchaseOrders.Count(purchaseOrderReq);

            return new PagingResponse<POList>(totalRecords, purchaseOrderReq.Pageno, purchaseOrderReq.Pagesize)
            {
                RowData = list,
            };
        }

        public POList? GetListById(int poId)
        {
            var listReq = new POListReq
            {
                Id = poId
            };

            return Uow.PurchaseOrders.GetPagedList(listReq).AsEnumerable().
                FirstOrDefault();
        }

        public POList? Checkout(POCheckoutReq checkoutReq)
        {
            var poId = Uow.PurchaseOrders.Checkout(checkoutReq);

            return GetListById(poId);
        }

        public void Delete(int PurchaseId)
        {
            var purchase = Uow.Purchases.GetById(PurchaseId);

            // PO and Bill Manager point at the same shared Purchase row.
            // Deleting from PO Manager must remove that same document before
            // convert-to-bill, otherwise Bill Manager still shows the orphaned row.
            if (purchase != null && !purchase.IsLocked)
            {
                Uow.Purchases.Find(c => c.PurchaseId == PurchaseId).ExecuteDelete();

                string docType = EnumHelper.DocType.Purchase.ToString();

                _deleteLogService.Add(docType, PurchaseId);
            }
        }

        public IEnumerable<PODetail> GetPODetail(int purchaseId)
        {
            return Uow.PurchaseOrders.GetPODetail(purchaseId);
        }

        public POList? CopyToBill(POCopyToBillReq copyToBillReq)
        {
            Uow.PurchaseOrders.CopyToBill(copyToBillReq);

            return GetListById(copyToBillReq.PurchaseId);
        }

        public string PrintPO(int purchaseId)
        {
            var compnayInfo = _companyService.GetDefault();

            var po = Uow.Reports.ReportPO(purchaseId);
            var poDetail = Uow.Reports.ReportPODetail(purchaseId).ToList();

            var rptPO = new RptPOView
            {
                Company = compnayInfo,
                RptPO = po,
                RptPODetail = poDetail
            };

            var poTemplate = "~/Views/Pdf/PO.cshtml";
            var pohtml = _pdfService.RenderTemplate(poTemplate, rptPO);

            var fileName = "PO-" + purchaseId.ToString() + ".pdf";
            string poFile = Path.Combine(_env.WebRootPath, "Pdf", fileName);

            using (var pdf = _pdfService.HtmlToPDF(pohtml))
            {
                pdf.SaveAs(poFile);
            }

            return poFile;
        }

        public POList? UpdateToBillStage(int purchaseId)
        {
            Uow.Purchases.Find(c => c.PurchaseId == purchaseId).ExecuteUpdate(setters => setters
            .SetProperty(x => x.StageId, x => 6)
            .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));

            Uow.Shipments.Allocation(purchaseId);

            Uow.VendorPayments.ApplyAdvance(purchaseId);

            return GetListById(purchaseId);
        }

    }
}
