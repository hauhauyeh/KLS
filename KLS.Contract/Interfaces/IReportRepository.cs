using KLS.Models;
using KLS.Models.Reports;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface IReportRepository : IRepository<RptPOView>
    {
        Invoice Invoice(int salesId);

        IQueryable<InvoiceDetail>? InvoiceDetail(int salesId);

        RptPO ReportPO(int purchaseId);

        IQueryable<RptPODetail> ReportPODetail(int purchaseId);

        IQueryable<RptPackingItem> PackingList(DocumentReq req);
    }
}
