using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using Microsoft.AspNetCore.Hosting;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class PromotionCategoryService : BaseService, IPromotionCategoryService
    {
        public PromotionCategoryService(IUnitOfWork uow) : base(uow)
        {

        }
    }
}
