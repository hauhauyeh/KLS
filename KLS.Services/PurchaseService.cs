using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Org.BouncyCastle.Utilities;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class PurchaseService : BaseService, IPurchaseService
    {
        private readonly IWebHostEnvironment _env;
        private readonly IItemService _itemService;

        public PurchaseService(IUnitOfWork uow, IWebHostEnvironment env, IItemService itemService) : base(uow)
        {
            _env = env;
            _itemService = itemService;
        }

        public PagingResponse<PurchaseList> GetAllPurchase(PurchaseListReq purchaseListReq)
        {
            var bills = Uow.Purchases.GetAllPurchase(purchaseListReq);

            var totalRecords = Uow.Purchases.CountAllPurchase(purchaseListReq);

            // Get absolute path to wwwroot/BillPdf
            var billPDfPath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "BillPdf");

            foreach (PurchaseList bill in bills)
            {
                var filePath = Path.Combine(billPDfPath, bill.PurchaseNumber + ".pdf");

                bill.IsPdfExist = File.Exists(filePath);
            }

            return new PagingResponse<PurchaseList>(totalRecords, purchaseListReq.Pageno, purchaseListReq.Pagesize)
            {
                RowData = bills,
            };
        }

        public Purchase GetById(int purchaseId)
        {
            return Uow.Purchases.GetById(purchaseId);
        }

        public PurchaseList? GetListById(int purchaseId)
        {
            var listReq = new PurchaseListReq
            {
                Id = purchaseId
            };

            return Uow.Purchases.GetAllPurchase(listReq).AsEnumerable().FirstOrDefault();
        }

        public void UpdateNotes(int purchaseId, string? notes)
        {
            Uow.Purchases.Find(c => c.PurchaseId == purchaseId).ExecuteUpdate(setters => setters
            .SetProperty(x => x.Notes, x => notes)
            .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));
        }

        public void UpdateDocNumber(int purchaseId, string? docNumber)
        {
            var purchase = GetById(purchaseId);

            if (purchase != null)
            {
                purchase.VendorDocNumber = docNumber;
                purchase.UpdatedAt = DateTime.UtcNow;

                Uow.Purchases.Update(purchase);
                Uow.Commit();
            }
        }

        public void UpdateInvoiceDate(int purchaseId, DateOnly? invoiceDate)
        {
            Uow.Purchases.Find(c => c.PurchaseId == purchaseId).ExecuteUpdate(setters => setters
            .SetProperty(x => x.InvoiceDate, x => invoiceDate)
            .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));
        }

        public void UpdateCommission(int purchaseId, decimal? commission)
        {
            Uow.Purchases.Find(c => c.PurchaseId == purchaseId).ExecuteUpdate(setters => setters
            .SetProperty(x => x.ImportCommission, x => commission)
            .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));
        }

        public void UpdatePallet(int purchaseId, int? palletCount)
        {
            Uow.Purchases.Find(c => c.PurchaseId == purchaseId).ExecuteUpdate(setters => setters
            .SetProperty(x => x.PalletCount, x => palletCount)
            .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));
        }

        public PurchaseList? UpdateNameDate(PurchaseUpdateReq updateReq)
        {
            Uow.Purchases.UpdateNameDate(updateReq);

            return GetListById(updateReq.PurchaseId);
        }

        public PurchaseList? Checkout(PurchaseCheckoutReq checkoutReq)
        {
            var purchaseId = Uow.Purchases.Checkout(checkoutReq);

            //send cost change notification
            var itemCostChange = Uow.Items.Find(c => c.IsCostChange == true).ToList();

            foreach (var item in itemCostChange)
            {
                _itemService.SendCostChangeNotification(item);
            }

            return GetListById(purchaseId);
        }

        public PurchaseList? UpdateContainerNumber(int purchaseId, string? containerNumber)
        {
            Uow.Purchases.Find(c => c.PurchaseId == purchaseId).ExecuteUpdate(setters => setters
            .SetProperty(x => x.ContainerNumber, x => containerNumber)
            .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));

            Uow.Purchases.FreightBillLink(purchaseId);

            return GetListById(purchaseId);
        }

        public PurchaseList? UpdatePartially(int purchaseId)
        {
            Uow.Purchases.UpdatePartially(purchaseId);

            return GetListById(purchaseId);
        }

        public void InjectPurchase(PurchaseInjectReq injectReq)
        {
            Uow.Purchases.InjectPurchase(injectReq);
        }

        public void DeletePurchase(int purchaseId)
        {
            var purchase = GetById(purchaseId);

            if (purchase != null && !purchase.IsLocked)
            {
                Uow.Purchases.Find(c => c.PurchaseId == purchaseId).ExecuteDelete();
            }
        }

        public void UploadBillPDF(PDFUploadReq pdfUploadReq)
        {
            var pdfbillfile = Path.Combine(_env.WebRootPath, Constants.PurchaseImagePath, pdfUploadReq.PurchaseNumber + ".pdf");

            if (System.IO.File.Exists(pdfbillfile))
            {
                PdfDocument oldpdf = new(pdfbillfile);

                string newfile = Path.Combine(_env.WebRootPath, Constants.PurchaseImagePath, "Temp-" + pdfUploadReq.PurchaseNumber + ".pdf");

                using (var fileStream = new FileStream(newfile, FileMode.Create, FileAccess.ReadWrite))
                {
                    pdfUploadReq.PDFFile?.CopyTo(fileStream);
                }

                //combined 2 file
                PdfDocument newpdffile = new(newfile);

                oldpdf.AppendPdf(newpdffile);

                if (oldpdf.PageCount > 0)
                    oldpdf.SaveAs(pdfbillfile);

                System.IO.File.Delete(newfile);
            }
            else
            {
                using (var fileStream = new FileStream(pdfbillfile, FileMode.Create))
                {
                    pdfUploadReq.PDFFile?.CopyTo(fileStream);
                }
            }
        }
    }
}
