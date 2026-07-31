using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ICustomerService
    {
        PagingResponse<CustomerList> GetPagedList(CustomerListReq customerListReq);

        CustomerDto GetById(int payeeId);

        void EnsureVisible(int payeeId);

        bool NameExists(string? payeeName, int payeeId);

        CustomerDto Create(CustomerDto customerDto);

        CustomerDto? Update(CustomerDto customerDto);

        void Delete(int payeeId);

        ICollection<PayeeSearch>? Search(PayeeSearchReq searchReq);

        void EmailPricesheet(int payeeId);

        void EmailStatement(int payeeId);

        byte[] Export();

        void Register(RegisterReq registerReq, string url);

        DateOnly GetNextShipDate(int payeeId);

        GeocodeBackfillResult GeocodeBackfill(bool overwriteExisting);
    }
}
