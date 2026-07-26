using KLS.Models;

namespace KLS.Contract.Services
{
    public interface IItemQuoteManagerService
    {
        IEnumerable<ItemQuoteManagerRow> GetRows(int payeeId);

        IEnumerable<ItemQuoteManagerRow> Inject(int payeeId);

        int Save(int payeeId);

        IEnumerable<ItemQuoteManagerRow> Clear(int payeeId);

        IEnumerable<ItemQuoteManagerRow> AddItem(int payeeId, ItemQuoteManagerAddItemReq req);

        IEnumerable<ItemQuoteManagerRow> Override(int payeeId, ItemQuoteManagerOverrideReq req);

        ItemQuoteManagerRow UpdateDraftRow(int payeeId, int tempQuoteId, ItemQuoteManagerUpdateDraftRowReq req);

        IEnumerable<ItemQuoteManagerRow> DeleteDraftRow(int payeeId, int tempQuoteId);
    }
}
