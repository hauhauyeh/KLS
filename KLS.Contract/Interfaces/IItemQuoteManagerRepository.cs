using KLS.Models;

namespace KLS.Contract.Interfaces
{
    public interface IItemQuoteManagerRepository
    {
        IQueryable<ItemQuoteManagerRow> GetRows(int payeeId);
    }
}
