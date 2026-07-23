namespace KLS.Contract.Interfaces
{
    /// <summary>
    /// Creates a fresh, self-contained <see cref="IUnitOfWork"/> (its own
    /// DbContext) for work that must not reuse the request-scoped unit of work —
    /// e.g. writing an EmailLog from a background send continuation after the
    /// originating request has ended.
    /// </summary>
    public interface IUnitOfWorkFactory
    {
        IUnitOfWork Create();
    }
}
