using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IDocumentService
    {
        string SalesOrder(DocumentReq documentReq);

        string PickTicket(DocumentReq documentReq);

        string Invoice(DocumentReq documentReq);

        string? PackingList(DocumentReq documentReq);

        string? LoadingList(DocumentReq documentReq);

        string? PackingLabel(DocumentReq req);
    }
}
