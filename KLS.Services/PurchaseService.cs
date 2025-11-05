using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
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

        public PurchaseService(IUnitOfWork uow, IWebHostEnvironment env) : base(uow)
        {
            _env = env;
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
