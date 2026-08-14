using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Models.Reports;
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
        private const string DsBilledValidationError = "DS billed bill can only edit price, comment, and account lines.";

        private readonly IWebHostEnvironment _env;
        private readonly IDeleteLogService _deleteLogService;
        private readonly ITwilioService _twilioService;

        public PurchaseService(IUnitOfWork uow, IWebHostEnvironment env, IDeleteLogService deleteLogService, ITwilioService twilioService) : base(uow)
        {
            _env = env;
            _deleteLogService = deleteLogService;
            _twilioService = twilioService;
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
            docNumber = NormalizeUpperRef(docNumber);

            if (docNumber == null)
                return false;

            return Uow.Purchases.Exists(c => c.VendorDocNumber == docNumber && c.PayeeId == payeeId && c.PurchaseId != purchaseId);
        }

        public PurchaseList? UpdateDocNumber(int purchaseId, string? docNumber)
        {
            docNumber = NormalizeUpperRef(docNumber);

            var purchase = GetById(purchaseId);

            if (purchase == null)
                return null;

            EnsureDropShipReceivedStageEditable(purchase);

            purchase.VendorDocNumber = docNumber;
            purchase.UpdatedAt = DateTime.UtcNow;

            Uow.Purchases.Update(purchase);
            Uow.Commit();

            Uow.Purchases.SyncDropShipSalesTransitFromPO(purchaseId);

            return GetListById(purchaseId);
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
            checkoutReq.VendorDocNumber = NormalizeUpperRef(checkoutReq.VendorDocNumber);
            checkoutReq.ContainerNumber = NormalizeUpperRef(checkoutReq.ContainerNumber);

            var purchaseId = Uow.Purchases.Checkout(checkoutReq);

            Uow.Shipments.AllocateVendorDirectInvcIfNeeded(purchaseId);

            //send cost change notification
            var itemCosts = Uow.Purchases.GetItemCostChange(purchaseId).ToList();

            SendCostChangeNotification(itemCosts);

            return GetListById(purchaseId);
        }

        public PurchaseList? UpdateContainerNumber(int purchaseId, string? containerNumber)
        {
            containerNumber = NormalizeUpperRef(containerNumber);

            var purchase = GetById(purchaseId);

            if (purchase == null)
                return null;

            EnsureDropShipReceivedStageEditable(purchase);

            Uow.Purchases.Find(c => c.PurchaseId == purchaseId).ExecuteUpdate(setters => setters
            .SetProperty(x => x.ContainerNumber, x => containerNumber)
            .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));

            Uow.Purchases.FreightBillLink(purchaseId);

            Uow.Purchases.SyncDropShipSalesTransitFromPO(purchaseId);

            return GetListById(purchaseId);
        }

        private static string? NormalizeUpperRef(string? value)
        {
            var normalized = value?.Trim().ToUpperInvariant();
            return string.IsNullOrEmpty(normalized) ? null : normalized;
        }

        private static void EnsureDropShipReceivedStageEditable(Purchase purchase)
        {
            if (purchase.IsDropShip && (purchase.StageId == 4 || purchase.StageId == 5))
                throw new ArgumentException("Read only. Drop-ship receipt is already confirmed. Use Backorder DS for remaining quantities.");
        }

        public PurchaseList? UpdateFactorPO(int purchaseId, string? factorPO)
        {
            factorPO = string.IsNullOrWhiteSpace(factorPO) ? null : factorPO.Trim();

            var purchase = GetById(purchaseId);

            if (purchase == null)
                return null;

            EnsureDropShipReceivedStageEditable(purchase);

            var updated = Uow.Purchases.Find(c => c.PurchaseId == purchaseId && !c.IsLocked).ExecuteUpdate(setters => setters
            .SetProperty(x => x.FactorPO, x => factorPO)
            .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));

            if (updated == 0)
                throw new ArgumentException("Purchase was not found or is locked.");

            return GetListById(purchaseId);
        }

        public PurchaseList? UpdatePartially(int purchaseId)
        {
            var purchase = GetById(purchaseId);

            if (purchase?.IsDropShip == true && purchase.StageId == 6)
            {
                ValidateDropShipBilledPartialUpdate(purchase);
            }

            Uow.Purchases.UpdatePartially(purchaseId);

            return GetListById(purchaseId);
        }

        private void ValidateDropShipBilledPartialUpdate(Purchase purchase)
        {
            if (!purchase.PayeeId.HasValue)
                throw new ArgumentException(DsBilledValidationError);

            var savedRows = Uow.Purchases.GetPurchaseDetailValidationRows(purchase.PurchaseId).ToList();
            var tempRows = Uow.TempPurchases.Find(c => c.EmpId == UserContext.EmpId
                && c.PayeeId == purchase.PayeeId.Value
                && c.PurchaseId == purchase.PurchaseId)
                .ToList();

            if (savedRows.Count == 0 || tempRows.Count == 0)
                throw new ArgumentException(DsBilledValidationError);

            var duplicateExistingRows = tempRows
                .Where(c => c.PurchaseDetailId.HasValue)
                .GroupBy(c => c.PurchaseDetailId!.Value)
                .Any(c => c.Count() > 1);

            if (duplicateExistingRows)
                throw new ArgumentException(DsBilledValidationError);

            var savedById = savedRows.ToDictionary(c => c.PurchaseDetailId);
            var tempByDetailId = tempRows
                .Where(c => c.PurchaseDetailId.HasValue)
                .ToDictionary(c => c.PurchaseDetailId!.Value);

            foreach (var saved in savedRows)
            {
                if (!tempByDetailId.TryGetValue(saved.PurchaseDetailId, out var temp))
                    throw new ArgumentException(DsBilledValidationError);

                if (IsDeleted(temp))
                    throw new ArgumentException(DsBilledValidationError);

                if (IsItemLine(saved.LineType))
                {
                    if (!IsItemLine(temp.LineType) || HasProtectedExistingRowChange(saved, temp))
                        throw new ArgumentException(DsBilledValidationError);
                }
                else if (IsAccountLine(saved.LineType))
                {
                    if (!IsAccountLine(temp.LineType) || HasProtectedExistingRowChange(saved, temp))
                        throw new ArgumentException(DsBilledValidationError);
                }
                else
                {
                    throw new ArgumentException(DsBilledValidationError);
                }
            }

            foreach (var temp in tempRows)
            {
                if (temp.PurchaseDetailId.HasValue)
                {
                    if (!savedById.ContainsKey(temp.PurchaseDetailId.Value))
                        throw new ArgumentException(DsBilledValidationError);

                    continue;
                }

                if (!IsAccountLine(temp.LineType))
                    throw new ArgumentException(DsBilledValidationError);
            }
        }

        private static bool HasProtectedExistingRowChange(PurchaseDetailValidationRow saved, TempPurchase temp)
        {
            return saved.PurchaseDetailId != temp.PurchaseDetailId
                || saved.PurchaseId != temp.PurchaseId
                || saved.LineId != temp.LineId
                || !SameText(saved.LineType, temp.LineType)
                || saved.ItemId != temp.ItemId
                || saved.AccountId != temp.AccountId
                || saved.ItemUnitId != temp.ItemUnitId
                || !SameText(saved.Unit, temp.Unit)
                || saved.IsFree != temp.IsFree
                || saved.IsOut != temp.IsOut
                || saved.IsCRCG != temp.IsCRCG
                || !SameDecimal(saved.OrdQty0, temp.OrdQty0)
                || !SameDecimal(saved.ShipQty, temp.ShipQty)
                || !SameDecimal(saved.BillQty, temp.BillQty)
                || !SameDecimal(saved.OrdQty1, temp.OrdQty1)
                || !SameDecimal(saved.ReceiveQty, temp.ReceiveQty)
                || !SameDecimal(saved.FinalQty, temp.FinalQty)
                || !SameDecimal(saved.FactorToBase, temp.FactorToBase)
                || saved.ExpiryDate != temp.ExpiryDate
                || !SameDecimal(saved.CustomDutyRate, temp.CustomDutyRate)
                || !SameDecimal(saved.TariffPercent, temp.TariffPercent)
                || !SameDecimal(saved.ImportCommission, temp.ImportCommission)
                || !SameDecimal(saved.ItemVolume, temp.ItemVolume);
        }

        private static bool IsItemLine(string? lineType)
        {
            return SameText(lineType, EnumHelper.LineType.I.ToString());
        }

        private static bool IsAccountLine(string? lineType)
        {
            return SameText(lineType, EnumHelper.LineType.A.ToString());
        }

        private static bool IsDeleted(TempPurchase temp)
        {
            return SameText(temp.ChangeStatus, EnumHelper.ChangeStatus.D.ToString());
        }

        private static bool SameText(string? left, string? right)
        {
            return string.Equals(NormalizeCompareText(left), NormalizeCompareText(right), StringComparison.OrdinalIgnoreCase);
        }

        private static string? NormalizeCompareText(string? value)
        {
            var normalized = value?.Trim();
            return string.IsNullOrEmpty(normalized) ? null : normalized;
        }

        private static bool SameDecimal(decimal? left, decimal? right)
        {
            return Nullable.Equals(left, right);
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
                if (purchase.IsDropShip && purchase.DropShipSalesId != null)
                {
                    CancelLinkedDropShipPurchaseDelete(purchase, purchaseId);
                }
                else
                {
                    Uow.Purchases.Find(c => c.PurchaseId == purchaseId).ExecuteDelete();
                }

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

        // Vendor purchase history panel — passthrough. SP returns 1-year per-item
        // rollup of the vendor's purchase history (all stages, denormalized
        // LastPurchaseStage chip data). Frontend drawer in po-add-edit and
        // purchase-add-edit consumes this for the side history panel.
        public IEnumerable<VendorPurchaseHistoryPanelRow> VendorPurchaseHistoryPanel(int payeeId)
        {
            return Uow.Reports.VendorPurchaseHistoryPanel(payeeId).ToList();
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

        public void SendCostChangeNotification(List<PurchaseItemCostList> items)
        {
            if (items == null || !items.Any())
                return;

            var employees = (from p in Uow.Payees.GetAll()
                             join e in Uow.Employees.GetAll()
                             on p.PayeeId equals e.PayeeId
                             where e.IsPriceChangeNotify == true
                                   && p.IsClosed == false
                                   && !string.IsNullOrEmpty(p.Phone1)
                             select p).AsEnumerable();

            foreach (var item in items)
            {
                var perc = Math.Round(item.CostChangePercent ?? 0, 2);

                var sign = perc >= 0 ? "+" : "";

                var msg = $"({item.ItemCode}) {item.ItemName} {sign}{perc:N2}% to {string.Format("{0:c}", item.RecentCost)}";

                foreach (var emp in employees)
                {
                    _twilioService.SendMessage(emp.Phone1, msg);
                }
            }
        }
    }
}
