namespace KLS.Contract.Services
{
    public interface ISalesOrderDocumentStageEffectService
    {
        void ApplyAfterSuccess(int salesId, string actionKey);
    }
}
