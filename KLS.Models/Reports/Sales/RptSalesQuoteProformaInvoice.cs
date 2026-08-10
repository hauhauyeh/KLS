namespace KLS.Models.Reports
{
    public class RptSalesQuoteProformaInvoice : RptSalesQuote
    {
        public string? LineCustomerPONumber { get; set; }

        public bool IsLineCustomerPOProforma => !string.IsNullOrWhiteSpace(LineCustomerPONumber);

        public string MainDocumentLabel => IsLineCustomerPOProforma ? "Customer PO#" : "Quote #";

        public string MainDocumentNumber => IsLineCustomerPOProforma
            ? LineCustomerPONumber!
            : Quote?.QuoteNumber.ToString() ?? string.Empty;

        public string ReferenceLabel => IsLineCustomerPOProforma ? "Ref" : "Customer PO#";

        public string ReferenceNumber => IsLineCustomerPOProforma
            ? $"Quote #{Quote?.QuoteNumber}"
            : string.Empty;
    }
}
