using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Linq.Expressions;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Data.Repositories
{
    public class KLSRepository<T> : IRepository<T> where T : class
    {
        protected readonly KLSDBContext DbContext;

        public KLSRepository(KLSDBContext dbContext)
        {
            this.DbContext = dbContext;
        }

        public virtual IQueryable<T> GetAll()
        {
            return this.DbContext.Set<T>().AsNoTracking();
        }

        public virtual T GetById(int Id)
        {
            return DbContext.Set<T>().Find(Id);
        }

        public virtual bool Exists(Expression<Func<T, bool>> predicate)
        {
            return this.DbContext.Set<T>().Any(predicate);
        }

        public IQueryable<T> Find(Expression<Func<T, bool>> expression)
        {
            return this.DbContext.Set<T>().Where(expression);
        }

        public virtual void Add(T entity)
        {
            this.DbContext.Set<T>().Add(entity);
        }

        public void AddRange(IEnumerable<T> entities)
        {
            this.DbContext.AddRange(entities);
        }

        public void Update(T entity)
        {
            this.DbContext.Set<T>().Attach(entity);
            this.DbContext.Entry(entity).State = EntityState.Modified;
        }

        public void Remove(T entity)
        {
            this.DbContext.Set<T>().Remove(entity);
        }

        public void RemoveById(int id)
        {
            var entity = GetById(id);

            if (entity != null)
            {
                Remove(entity);
            }
        }

        public void RemoveRange(IEnumerable<int> ids)
        {
            foreach (var id in ids)
            {
                var entity = GetById(id);

                if (entity != null)
                {
                    Remove(entity);
                }
            }
        }

        public virtual void Reload(T entity)
        {
            this.DbContext.Entry(entity).Reload();
        }

        //public void Delete(T entity)
        //{
        //    this.DbContext.Set<T>().Remove(entity);
        //}

        //public void Delete(int id)
        //{
        //    var entity = GetById(id);

        //    if (entity != null)
        //    {
        //        Delete(entity);
        //    }
        //}

        //public void DeleteBulk(List<int> ids)
        //{
        //    foreach (var id in ids)
        //    {
        //        var entity = GetById(id);

        //        if (entity != null)
        //        {
        //            Delete(entity);
        //        }
        //    }
        //}
    }
}
