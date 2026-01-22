using KLS.Models;
using KLS.Models.Reports;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IReportService
    {
        RptInvoice Invoice(int salesId);

        RptCustStmt CustStmt(int payeeId);

        RptPackingList PackingList(DocumentReq req);
    }
}
