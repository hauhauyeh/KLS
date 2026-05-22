using KLS.Models;

namespace KLS.Contract.Interfaces
{
    public interface ITempSalesQuoteRepository : IRepository<TempSalesQuote>
    {
        IQueryable<TempSalesQuoteItem>? GetList(TempSalesQuoteReq req);
        IQueryable<ItemSearch> Search(TempSalesQuoteReq req);
        TempSalesQuoteItem? AddLine(SalesQuoteAddLineRequest req);
    }
}
