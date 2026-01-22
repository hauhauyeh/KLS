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

        public PagingResponse<PurchaseOrderList> GetPagedList(PurchaseOrderReq purchaseOrderReq)
        {
            var list = Uow.PurchaseOrders.GetPagedList(purchaseOrderReq);

            var totalRecords = Uow.PurchaseOrders.Count(purchaseOrderReq);

            return new PagingResponse<PurchaseOrderList>(totalRecords, purchaseOrderReq.Pageno, purchaseOrderReq.Pagesize)
            {
                RowData = list,
            };
        }

        public PurchaseOrderList? GetListById(int poId)
        {
            var listReq = new PurchaseOrderReq
            {
                Id = poId
            };

            return Uow.PurchaseOrders.GetPagedList(listReq).AsEnumerable().
                FirstOrDefault();
        }

        public PurchaseOrderList? Checkout(PurchaseOrderCheckoutReq checkoutReq)
        {
            var poId = Uow.PurchaseOrders.Checkout(checkoutReq);

            return GetListById(poId);
        }

        public void Delete(int PurchaseId)
        {
            var purchase = Uow.Purchases.GetById(PurchaseId);

            if (purchase != null && purchase.StageId == 1)
            {
                Uow.Purchases.Find(c => c.PurchaseId == PurchaseId).ExecuteDelete();

                string docType = EnumHelper.DocType.Purchase.ToString();

                _deleteLogService.Add(docType, PurchaseId);
            }
        }

        //public void SaveAdvancePayment(POAdvancePaymentReq advancePaymentReq)
        //{
        //    Uow.PurchaseOrders.SaveAdvancePayment(advancePaymentReq);
        //}

        //public void DeleteAdvancePayment(int poId)
        //{
        //    Uow.PurchaseOrders.DeleteAdvancePayment(poId);
        //}

        public IEnumerable<PODetail> GetPODetail(int purchaseId)
        {
            return Uow.PurchaseOrders.GetPODetail(purchaseId);
        }

        public PurchaseOrderList? CopyToBill(POCopyToBillReq copyToBillReq)
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

        public PurchaseOrderList? UpdateToBillStage(int purchaseId)
        {
            Uow.Purchases.Find(c => c.PurchaseId == purchaseId).ExecuteUpdate(setters => setters
            .SetProperty(x => x.StageId, x => 6)
            .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));

            return GetListById(purchaseId);
        }
    }
}
