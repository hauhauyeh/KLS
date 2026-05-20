using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Contract.Services;
using Microsoft.EntityFrameworkCore;
using IronPdf;
using Microsoft.AspNetCore.Hosting;
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
        private readonly IDeleteLogService _deleteLogService;

        public PurchaseService(IUnitOfWork uow, IWebHostEnvironment env, IItemService itemService, IDeleteLogService deleteLogService) : base(uow)
        {
            _env = env;
            _itemService = itemService;
            _deleteLogService = deleteLogService;
        }

        public PagingResponse<PurchaseList> GetPagedList(PurchaseListReq purchaseListReq)
        {
            var bills = Uow.Purchases.GetPagedList(purchaseListReq);

            var totalRecords = Uow.Purchases.Count(purchaseListReq);

            foreach (PurchaseList bill in bills)
            {
                bill.IsPdfExist = IsBillPdfExist(bill.PurchaseNumber);
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

            return Uow.Purchases.GetPagedList(listReq).AsEnumerable().FirstOrDefault();
        }

        public void UpdateNotes(int purchaseId, string? notes)
        {
            Uow.Purchases.Find(c => c.PurchaseId == purchaseId).ExecuteUpdate(setters => setters
            .SetProperty(x => x.Notes, x => notes)
            .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));
        }

        public bool DocNumberExists(int purchaseId, int payeeId, string? docNumber)
        {
            if (string.IsNullOrEmpty(docNumber))
                return false;

            return Uow.Purchases.Exists(c => c.VendorDocNumber == docNumber && c.PayeeId == payeeId && c.PurchaseId != purchaseId);
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

            //foreach (var item in itemCostChange)
            //{
            //    //_itemService.SendCostChangeNotification(item);
            //}

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

        public void Inject(PurchaseInjectReq injectReq)
        {
            Uow.Purchases.Inject(injectReq);
        }

        public void Delete(int purchaseId)
        {
            var purchase = GetById(purchaseId);

            if (purchase != null && !purchase.IsLocked)
            {
                Uow.Purchases.Find(c => c.PurchaseId == purchaseId).ExecuteDelete();

                string docType = EnumHelper.DocType.Purchase.ToString();

                _deleteLogService.Add(docType, purchaseId);
            }
        }

        public void UploadBillPDF(PDFUploadReq pdfUploadReq)
        {
            var pdfBillPath = Path.Combine(_env.WebRootPath, Constants.PurchaseImagePath);

            var pdfbillfile = Path.Combine(pdfBillPath, pdfUploadReq.PurchaseNumber + ".pdf");

            if (IsBillPdfExist(pdfUploadReq.PurchaseNumber))
            {
                PdfDocument oldpdf = new(pdfbillfile);

                string newfile = Path.Combine(pdfBillPath, "Temp-" + pdfUploadReq.PurchaseNumber + ".pdf");

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

        public bool IsBillPdfExist(int purchaseNumber)
        {
            // Get absolute path to wwwroot/BillPdf
            var pdfFile = Path.Combine(_env.WebRootPath, "BillPdf", purchaseNumber + ".pdf");

            return File.Exists(pdfFile);
        }

        public PurchaseSeePayment SeePayment(int purchaseId)
        {
            var payments = Uow.VendorPayments.GetByPurchaseId(purchaseId).ToList();

            return new PurchaseSeePayment
            {
                Purchase = GetById(purchaseId),
                VendorPayments = payments
            };
        }

        public IEnumerable<AssignedShipment>? AssignedShipments(int purchaseId, bool isShipment)
        {
            var shipments = Uow.Purchases.AssignedShipments(purchaseId, isShipment).ToList();

            var result = shipments.GroupBy(r => new
            {
                r.ShipmentId,
                r.ShipmentType,
                r.ContainerType,
                r.ContainerNo,
                r.Status,
                r.PayeeName,
                r.IsLocked
            })
            .Select(g => new AssignedShipment
            {
                ShipmentPurchaseId = g.First().ShipmentPurchaseId,
                ShipmentId = g.Key.ShipmentId,
                ShipmentType = g.Key.ShipmentType,
                ContainerType = g.Key.ContainerType,
                ContainerNo = g.Key.ContainerNo,
                Status = g.Key.Status,
                PayeeName = g.Key.PayeeName,
                IsShipmentPaid = g.Key.IsLocked,

                Charges = g.Where(c => c.ChargeId != null)
                .Select(x => new ShipmentCharge
                {
                    ChargeId = x.ChargeId!.Value,
                    ShipmentId = g.Key.ShipmentId,
                    AllocationMethod = x.AllocationMethod,
                    ChargeType = x.ChargeType,
                    ChargeAmount = x.ChargeAmount ?? 0m,
                    Notes = x.Notes,
                    UsedMethod = x.UsedMethod
                }).ToList()
            }).ToList();

            return result;
        }

        public void AssignShipment(POCopyToBillReq copyToBillReq)
        {
            Uow.Shipments.AssignShipment(copyToBillReq);
        }

        public IEnumerable<PurchaseOpenBill>? GetOpenBills(int payeeId)
        {
            return Uow.Purchases
                .Find(c => c.PayeeId == payeeId && c.AmountDue > 0)
                .Select(c => new PurchaseOpenBill
                {
                    PurchaseId = c.PurchaseId,
                    PurchaseNumber = c.PurchaseNumber,
                    ArrivalDate = c.ArrivalDate,
                    DueDate = c.DueDate,
                    PurchaseTotal = c.PurchaseTotal,
                    PaymentApplied = c.PaymentApplied,
                    AmountDue = c.AmountDue
                })
                .OrderBy(c => c.ArrivalDate)
                .ThenBy(c => c.PurchaseNumber)
                .ToList();
        }

        public PurchaseDetailDto? GetPurchaseDetails(int purchaseId)
        {
            var details = Uow.Purchases.GetPurchaseDetails(purchaseId);

            return new PurchaseDetailDto
            {
                Purchase = GetListById(purchaseId),
                PurchaseDetails = details?.ToList()
            };
        }
    }
}
