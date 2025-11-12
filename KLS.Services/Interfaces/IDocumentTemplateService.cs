using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface IDocumentTemplateService
    {
        IQueryable<DocumentTemplate> GetAllDocumentTemplate();

        DocumentTemplate? GetById(int docTemplateId);

        bool NameExists(DocumentTemplate documentTemplate);

        DocumentTemplate CreateDocumentTemplate(DocumentTemplate documentTemplate);

        DocumentTemplate? UpdateDocumentTemplate(DocumentTemplate documentTemplate);

        void DeleteDocumentTemplate(int docTemplateId);
    }
}
