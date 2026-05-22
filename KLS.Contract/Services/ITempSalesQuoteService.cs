using KLS.Models;

namespace KLS.Contract.Services
{
    public interface ITempSalesQuoteService
    {
        IEnumerable<TempSalesQuoteItem>? GetList(TempSalesQuoteReq req);
        TempSalesQuoteItem Create(TempSalesQuoteItem item);
        TempSalesQuoteItem Update(TempSalesQuoteItem item);
        TempSalesQuoteItem UpdateUnit(TempSalesQuoteItem item);
        void Delete(int tempId);
        void Clear(TempSalesQuoteReq req);
        IEnumerable<ItemSearch> Search(TempSalesQuoteReq req);
        TempSalesQuoteItem? AddLine(SalesQuoteAddLineRequest req);
    }
}
