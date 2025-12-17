using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class SourceDocTypeService : BaseService, ISourceDocTypeService
    {
        public SourceDocTypeService(IUnitOfWork uow) : base(uow)
        {
        }

        public IEnumerable<SourceDocType>? GetAllDocTypes()
        {
            return Uow.SourceDocTypes.GetAll();
        }
    }
}
