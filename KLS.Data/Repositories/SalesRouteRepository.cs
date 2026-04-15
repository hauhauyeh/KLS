using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Data.Repositories
{
    public class SalesRouteRepository : KLSRepository<SalesRoute>, ISalesRouteRepository
    {
        public SalesRouteRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        public void SyncByDate(DateOnly shipDate)
        {
            var ShipDateParam = new SqlParameter("@ShipDate", shipDate);

            DbContext.Database.ExecuteSqlRaw("[dbo].[SalesRoute_SyncByDate] @ShipDate", ShipDateParam);
        }

        public bool CheckZeroPrice(PrintInvoiceReq printInvoiceReq)
        {
            var ShipDateParam = printInvoiceReq.ShipDate.HasValue ? new SqlParameter("@ShipDate", printInvoiceReq.ShipDate) : new SqlParameter("@ShipDate", DBNull.Value);

            var ShipRouteParam = string.IsNullOrEmpty(printInvoiceReq.ShipRoute) ? new SqlParameter("@ShipRoute", DBNull.Value) : new SqlParameter("@ShipRoute", printInvoiceReq.ShipRoute);

            var SalesIdParam = printInvoiceReq.SalesId.HasValue ? new SqlParameter("@SalesId", printInvoiceReq.SalesId) : new SqlParameter("@SalesId", DBNull.Value);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var IsPrint = new SqlParameter()
            {
                ParameterName = "@IsPrint",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Bit
            };

            DbContext.Database.ExecuteSqlRaw("[dbo].[Sales_CheckZeroPrice] @ShipDate,@ShipRoute,@SalesId,@EmpId,@IsPrint OUTPUT", ShipDateParam, ShipRouteParam, SalesIdParam, EmpIdParam, IsPrint);

            return Convert.ToBoolean(IsPrint.Value);
        }
    }
}
