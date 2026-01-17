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
    public class TempBombSalesRepository : KLSRepository<TempBombSales>, ITempBombSalesRepository
    {
        public TempBombSalesRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        public IQueryable<BombSalesItem> GetList(bool checkAgain, int? tempId)
        {
            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var CheckAgainParam = new SqlParameter("@CheckAgain", checkAgain);

            var TempIdParam = tempId.HasValue ? new SqlParameter("@TempId", tempId) : new SqlParameter("@TempId", DBNull.Value);

            return DbContext.BombSalesItem.FromSqlRaw("[dbo].[TempBombSales_GetList] @EmpId,@CheckAgain,@TempId", EmpIdParam, CheckAgainParam, TempIdParam);
        }

        public void Inject(BombSalesReq bombSalesReq)
        {
            var DateRangeParam = string.IsNullOrEmpty(bombSalesReq.DateRange) ? new SqlParameter("@DateRange", DBNull.Value) : new SqlParameter("@DateRange", bombSalesReq.DateRange);

            var ShipDateParam = bombSalesReq.ShipDate.HasValue ? new SqlParameter("@ShipDate", bombSalesReq.ShipDate) : new SqlParameter("@ShipDate", DBNull.Value);

            var ItemIdParam = bombSalesReq.ItemId.HasValue ? new SqlParameter("@ItemId", bombSalesReq.ItemId) : new SqlParameter("@ItemId", DBNull.Value);

            var ShipQtyParam = bombSalesReq.ShipQty.HasValue ? new SqlParameter("@ShipQty", bombSalesReq.ShipQty) : new SqlParameter("@ShipQty", DBNull.Value);

            var UnitParam = string.IsNullOrEmpty(bombSalesReq.Unit) ? new SqlParameter("@Unit", DBNull.Value) : new SqlParameter("@Unit", bombSalesReq.Unit);

            var PriceParam = bombSalesReq.Price.HasValue ? new SqlParameter("@Price", bombSalesReq.Price) : new SqlParameter("@Price", DBNull.Value);

            var ShipRouteParam = string.IsNullOrEmpty(bombSalesReq.ShipRoute) ? new SqlParameter("@ShipRoute", DBNull.Value) : new SqlParameter("@ShipRoute", bombSalesReq.ShipRoute);

            var PayeeIdParam = bombSalesReq.PayeeId.HasValue ? new SqlParameter("@PayeeId", bombSalesReq.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value);

            var SalesNumberParam = bombSalesReq.SalesNumber.HasValue ? new SqlParameter("@SalesNumber", bombSalesReq.SalesNumber) : new SqlParameter("@SalesNumber", DBNull.Value);

            var IsPoundParam = new SqlParameter("@IsPound", bombSalesReq.IsPound);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            DbContext.Database.ExecuteSqlRaw("[dbo].[TempBombSales_Inject] @DateRange,@ShipDate,@ItemId,@ShipQty,@Unit,@Price,@ShipRoute,@PayeeId,@SalesNumber,@IsPound,@EmpId", DateRangeParam, ShipDateParam, ItemIdParam, ShipQtyParam, UnitParam, PriceParam, ShipRouteParam, PayeeIdParam, SalesNumberParam, IsPoundParam, EmpIdParam);
        }

        public void SaveBomb()
        {
            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            DbContext.Database.ExecuteSqlRaw("[dbo].[TempBombSales_Save] @EmpId", EmpIdParam);
        }
    }
}
