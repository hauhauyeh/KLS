using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IPromotionService
    {
        PagingResponse<PromotionList> GetPagedList(PromotionListReq promotionListReq);

        Promotion GetById(int promotionId);

        bool ExistsName(Promotion promotion);

        Promotion Create(Promotion promotion);

        Promotion? Update(Promotion promotion);

        void Delete(int promotionId);
    }
}
