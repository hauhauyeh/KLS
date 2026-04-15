using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ISalesStageService
    {
        IEnumerable<SalesStage> GetList();

        SalesStage MarkInvoicePrinted(int salesId);

        SalesStage MarkPickTicketPrinted(int salesId);
    }
}
