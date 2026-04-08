using KLS.Models;

namespace KLS.Contract.Services
{
    public interface IContactService
    {
        void SendMessage(ContactMessageReq req);
    }
}
