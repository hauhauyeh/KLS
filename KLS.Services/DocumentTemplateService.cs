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
    public class DocumentTemplateService : BaseService, IDocumentTemplateService
    {
        public DocumentTemplateService(IUnitOfWork uow) : base(uow)
        {

        }

        public IQueryable<DocumentTemplate> GetAllDocumentTemplate()
        {
            return Uow.DocumentTemplates.GetAll();
        }

        public DocumentTemplate? GetById(int docTemplateId)
        {
            return Uow.DocumentTemplates.GetById(docTemplateId);
        }

        public bool NameExists(DocumentTemplate documentTemplate)
        {
            return Uow.DocumentTemplates.Exists(c => c.DocumentName.ToLower() == documentTemplate.DocumentName.ToLower() && c.DocTemplateId != documentTemplate.DocTemplateId);
        }

        public DocumentTemplate CreateDocumentTemplate(DocumentTemplate documentTemplate)
        {
            Uow.DocumentTemplates.Add(documentTemplate);
            Uow.Commit();

            return documentTemplate;
        }

        public DocumentTemplate? UpdateDocumentTemplate(DocumentTemplate documentTemplate)
        {
            var existing = GetById(documentTemplate.DocTemplateId);

            if (existing != null)
            {
                existing.DocumentType = documentTemplate.DocumentType;
                existing.DocumentName = documentTemplate.DocumentName;
                existing.Description = documentTemplate.Description;
                existing.HtmlContent = documentTemplate.HtmlContent;
                existing.CssContent = documentTemplate.CssContent;
                existing.OrgHtmlContent = documentTemplate.OrgHtmlContent;
                existing.OrgCssContent = documentTemplate.OrgCssContent;
                existing.PaperSize = documentTemplate.PaperSize;
                existing.Orientation = documentTemplate.Orientation;
                existing.Version = documentTemplate.Version;
                existing.IsActive = documentTemplate.IsActive;

                existing.UpdatedAt = DateTime.UtcNow;

                Uow.DocumentTemplates.Update(existing);
                Uow.Commit();
            }

            return existing;
        }

        public void DeleteDocumentTemplate(int docTemplateId)
        {
            Uow.DocumentTemplates.RemoveById(docTemplateId);
            Uow.Commit();
        }
    }
}
