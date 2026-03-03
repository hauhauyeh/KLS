using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class Rest365Service : BaseService, IRest365Service
    {
        public Rest365Service(IUnitOfWork uow) : base(uow)
        {

        }

        public IEnumerable<Rest365> GetList()
        {
            return Uow.Rest365.GetAll().OrderBy(h => h.CustomerName).ToList();
        }

        public Rest365? GetById(int rest365Id)
        {
            return Uow.Rest365.Find(r => r.Rest365Id == rest365Id).Include(r=>r.Rest365Details).FirstOrDefault();
        }

        public bool NameExists(Rest365 rest365)
        {
            return Uow.Rest365.Exists(c => c.CustomerName.ToLower() == rest365.CustomerName.ToLower() && c.Rest365Id != rest365.Rest365Id);
        }

        public Rest365 Create(Rest365 rest365)
        {
            Uow.Rest365.Add(rest365);
            Uow.Commit();

            return rest365;
        }

        public Rest365? Update(Rest365 rest365)
        {
            var existing = GetById(rest365.Rest365Id);

            if (existing != null)
            {
                existing.CustomerName = rest365.CustomerName;
                existing.Host = rest365.Host;
                existing.Username = rest365.Username;
                existing.Password = rest365.Password;
                existing.FolderPath = rest365.FolderPath;
                existing.Inactive = rest365.Inactive;
                existing.UpdatedAt = DateTime.UtcNow;

                Uow.Rest365.Update(existing);
                Uow.Commit();
            }

            return existing;
        }

        public void Inactive(int rest365Id)
        {
            var entity = Uow.Rest365.GetById(rest365Id);

            if (entity == null)
                throw new Exception("Record not found");

            entity.Inactive = !entity.Inactive;

            Uow.Rest365.Update(entity);
            Uow.Commit();
        }
    }
}
