using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;

namespace KLS.Services
{
    public class SalesQuoteService : BaseService, ISalesQuoteService
    {
        public SalesQuoteService(IUnitOfWork uow) : base(uow) { }

        public PagingResponse<SalesQuoteList>? GetPagedList(SalesQuoteListReq req)
        {
            var quotes = Uow.SalesQuotes.GetPagedList(req).ToList();
            var totalRecords = Uow.SalesQuotes.Count(req);

            return new PagingResponse<SalesQuoteList>(totalRecords, req.Pageno, req.Pagesize)
            {
                RowData = quotes,
            };
        }

        public SalesQuote GetById(int salesQuoteId)
        {
            return Uow.SalesQuotes.GetById(salesQuoteId);
        }

        public SalesQuoteDetailDto? GetDetail(int salesQuoteId)
        {
            var quote = Uow.SalesQuotes.GetById(salesQuoteId);
            if (quote == null) return null;

            var details = Uow.SalesQuotes.GetDetails(salesQuoteId);
            var payee = Uow.Payees.GetById(quote.PayeeId);

            return new SalesQuoteDetailDto
            {
                SalesQuote = quote,
                Details = details.ToList(),
                PayeeName = payee?.PayeeName
            };
        }

        public SalesQuoteList Insert(int salesQuoteId, int payeeId, DateOnly? expiryDate, string? notes, int statusId)
        {
            var newId = Uow.SalesQuotes.Insert(salesQuoteId, payeeId, expiryDate, notes, statusId);
            var listReq = new SalesQuoteListReq { Search = newId.ToString(), Pageno = 1, Pagesize = 1 };
            return Uow.SalesQuotes.GetPagedList(listReq).AsEnumerable().FirstOrDefault()!;
        }

        public SalesQuoteList Update(int salesQuoteId, int payeeId, DateOnly? expiryDate, string? notes)
        {
            Uow.SalesQuotes.Update(salesQuoteId, payeeId, expiryDate, notes);
            var listReq = new SalesQuoteListReq { Search = salesQuoteId.ToString(), Pageno = 1, Pagesize = 1 };
            return Uow.SalesQuotes.GetPagedList(listReq).AsEnumerable().FirstOrDefault()!;
        }

        public void Inject(int salesQuoteId)
        {
            Uow.SalesQuotes.Inject(salesQuoteId);
        }

        public void Delete(int salesQuoteId)
        {
            Uow.SalesQuotes.Delete(salesQuoteId);
        }

        public void UpdateStatus(int salesQuoteId, int statusId)
        {
            Uow.SalesQuotes.UpdateStatus(salesQuoteId, statusId);
        }

        public int ConvertToSales(int salesQuoteId)
        {
            Uow.SalesQuotes.ConvertToSales(salesQuoteId);
            return salesQuoteId;
        }

        public void EmailPdf(int salesQuoteId)
        {
            // TODO: Implement PDF email (same pattern as SalesService.EmailPdf)
        }
    }
}
