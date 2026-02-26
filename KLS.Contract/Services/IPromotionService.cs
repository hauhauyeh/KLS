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
        PagingResponse<PromotionList> GetPromotionList(PromotionListReq promotionListReq);

        Promotion GetById(int promotionId);

        bool ExistsName(Promotion promotion);

        Promotion CreatePromotion(Promotion promotion);

        Promotion? UpdatePromotion(Promotion promotion);

        void Delete(int promotionId);
    }
}
