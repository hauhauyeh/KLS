using KLS.Contract.Interfaces;

namespace KLS.Data.Repositories
{
    /// <summary>
    /// Produces a fresh <see cref="UnitOfWork"/> (new KLSDBContext, self-configured
    /// from the static connection string) on each call. Stateless.
    /// </summary>
    public class UnitOfWorkFactory : IUnitOfWorkFactory
    {
        public IUnitOfWork Create() => new UnitOfWork();
    }
}
