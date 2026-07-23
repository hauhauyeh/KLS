using KLS.Models;

namespace KLS.Contract.Services
{
    public interface ISalesQuoteService
    {
        PagingResponse<SalesQuoteList>? GetPagedList(SalesQuoteListReq req);
        SalesQuote GetById(int salesQuoteId);
        SalesQuoteDetailDto? GetDetail(int salesQuoteId);
        SalesQuoteEmailContextDto? GetEmailContext(int salesQuoteId);
        int Insert(int salesQuoteId, int payeeId, DateOnly? expiryDate, string? notes, int statusId);
        void Update(int salesQuoteId, int payeeId, DateOnly? expiryDate, string? notes);
        void Inject(int salesQuoteId);
        void Delete(int salesQuoteId);
        void UpdateStatus(int salesQuoteId, int statusId);
        SalesQuoteConvertResult ConvertToSales(int salesQuoteId);
        void EmailPdf(int salesQuoteId);
    }
}
