using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IDocumentTemplateService
    {
        IEnumerable<DocumentTemplate> GetList();

        DocumentTemplate? GetById(int docTemplateId);

        bool Exists(DocumentTemplate documentTemplate);

        DocumentTemplate Create(DocumentTemplate documentTemplate);

        DocumentTemplate? Update(DocumentTemplate documentTemplate);

        void Delete(int docTemplateId);
    }
}
