using KLS.Models;

namespace KLS.Contract.Services
{
    public interface ISalesQuoteService
    {
        PagingResponse<SalesQuoteList>? GetPagedList(SalesQuoteListReq req);
        SalesQuote GetById(int salesQuoteId);
        SalesQuoteDetailDto? GetDetail(int salesQuoteId);
        SalesQuoteList Insert(int salesQuoteId, int payeeId, DateOnly? expiryDate, string? notes, int statusId);
        SalesQuoteList Update(int salesQuoteId, int payeeId, DateOnly? expiryDate, string? notes);
        void Inject(int salesQuoteId);
        void Delete(int salesQuoteId);
        void UpdateStatus(int salesQuoteId, int statusId);
        int ConvertToSales(int salesQuoteId);
        void EmailPdf(int salesQuoteId);
    }
}
