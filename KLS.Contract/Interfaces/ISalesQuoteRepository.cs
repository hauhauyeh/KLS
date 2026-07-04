using KLS.Models;

namespace KLS.Contract.Interfaces
{
    public interface ISalesQuoteRepository : IRepository<SalesQuote>
    {
        IQueryable<SalesQuoteList> GetPagedList(SalesQuoteListReq req);
        int Count(SalesQuoteListReq req);
        int Insert(int salesQuoteId, int payeeId, DateOnly? expiryDate, string? notes, int statusId);
        int Update(int salesQuoteId, int payeeId, DateOnly? expiryDate, string? notes);
        void Inject(int salesQuoteId);
        void Delete(int salesQuoteId);
        IEnumerable<SalesQuoteDetailList> GetDetails(int salesQuoteId);
        void UpdateStatus(int salesQuoteId, int statusId);
        void ConvertToSales(int salesQuoteId);
    }
}
