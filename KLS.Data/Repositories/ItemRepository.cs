using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Data.Repositories;
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
    public class ItemRepository : KLSRepository<Item>, IItemRepository
    {
        public ItemRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<ItemSearch>? SearchItem(ItemSearchReq searchReq)
        {
            var TermParam = string.IsNullOrEmpty(searchReq.Term) ? new SqlParameter("@SearchTerm", DBNull.Value) : new SqlParameter("@SearchTerm", searchReq.Term);

            var IsActiveOnlyParam = new SqlParameter("@IsActiveOnly", searchReq.IsActiveOnly);

            return DbContext.ItemSearch.FromSqlRaw("[dbo].[Item_SearchByTerm] @SearchTerm,@IsActiveOnly", TermParam, IsActiveOnlyParam);
        }
    }
}