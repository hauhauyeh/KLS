using KLS.Models;

namespace KLS.Contract.Services
{
    public interface IArEmailPaymentInstructionRenderer
    {
        string Render(Company? company);
    }
}
