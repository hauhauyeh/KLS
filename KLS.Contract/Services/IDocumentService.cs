using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IDocumentService
    {
        string SalesOrder(DocumentReq documentReq);

        string ProformaInvoice(DocumentReq documentReq);

        string PickTicket(DocumentReq documentReq);

        string Invoice(DocumentReq documentReq);

        string? PackingList(DocumentReq documentReq);

        // TotalList intentionally reuses the LoadingList packing-section builder so the
        // standalone output matches the bundled LoadingList packing pages exactly.
        string? TotalList(DocumentReq documentReq);

        // TotalSplitList is a new standalone route report that splits outside boxes
        // for identical-looking lbs rows from different source sales.
        string? TotalSplitList(DocumentReq documentReq);

        // Standalone filtered packing-style reports that share PackingList.cshtml.
        string? HarvillsList(DocumentReq documentReq);

        string? StoreTotalList(DocumentReq documentReq);

        string? LoadingList(DocumentReq documentReq);

        // RouteLoadingList renders only the loading-list section from the bundled
        // LoadingList document for one selected date and route.
        string? RouteLoadingList(DocumentReq documentReq);

        string? PackingLabel(DocumentReq req);

        string Check(int vendorPaymentId);

        string SalesQuote(int salesQuoteId);
    }
}
