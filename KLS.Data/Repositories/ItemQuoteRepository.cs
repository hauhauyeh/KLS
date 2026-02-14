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
    public class ItemQuoteRepository : KLSRepository<ItemQuote>, IItemQuoteRepository
    {
        public ItemQuoteRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public int Build(ItemQuoteBuildReq buildReq)
        {
            var PayeeIdParam = new SqlParameter("@PayeeId", buildReq.PayeeId);

            var ModeParam = new SqlParameter("@Mode", buildReq.BuildMode);

            var IsAppendParam = new SqlParameter("@IsAppend", buildReq.IsAppend);

            var TargetCustIdParam = buildReq.TargetCustId.HasValue ? new SqlParameter("@TargetCustId", buildReq.TargetCustId) : new SqlParameter("@TargetCustId", DBNull.Value);

            var CatIdsParam = string.IsNullOrEmpty(buildReq.CatIds) ? new SqlParameter("@CatIds", DBNull.Value) : new SqlParameter("@CatIds", buildReq.CatIds);

            var BuildWithPriceParam = new SqlParameter("@BuildWithPrice", buildReq.BuildWithPrice);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var OwnListCountParam = new SqlParameter()
            {
                ParameterName = "@OwnListCount",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };

            DbContext.Database.ExecuteSqlRaw("[ItemQuote_Build] @PayeeId,@Mode,@IsAppend,@TargetCustId,@CatIds,@BuildWithPrice,@EmpId,@OwnListCount OUTPUT", PayeeIdParam, ModeParam, IsAppendParam, TargetCustIdParam, CatIdsParam, BuildWithPriceParam, EmpIdParam, OwnListCountParam);

            return Convert.ToInt32(OwnListCountParam.Value);
        }

        public void Inject(int payeeId)
        {
            var PayeeIdParam = new SqlParameter("@PayeeId", payeeId);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            DbContext.Database.ExecuteSqlRaw("[ItemQuote_Inject] @PayeeId,@EmpId", PayeeIdParam, EmpIdParam);
        }

        public void Save(int payeeId)
        {
            var PayeeIdParam = new SqlParameter("@PayeeId", payeeId);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            DbContext.Database.ExecuteSqlRaw("[ItemQuote_Insert] @PayeeId,@EmpId", PayeeIdParam, EmpIdParam);
        }

        public IQueryable<TargetQuotePrice> GetTargetrPrice(int itemId, string? filterby)
        {
            var ItemIdParam = new SqlParameter("@ItemId", itemId);

            var FilterbyParam = string.IsNullOrEmpty(filterby) ? new SqlParameter("@Filterby", DBNull.Value) : new SqlParameter("@Filterby", filterby);

            return DbContext.TargetQuotePrice.FromSqlRaw("[ItemQuote_GetTargetPrice] @ItemId,@Filterby", ItemIdParam, FilterbyParam);
        }
    }
}
