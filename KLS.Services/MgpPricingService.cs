using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;

namespace KLS.Services
{
    public class MgpPricingService : BaseService, IMgpPricingService
    {
        public MgpPricingService(IUnitOfWork uow) : base(uow)
        {
        }

        public List<MgpPriceSheetTargetDto> GetPriceSheetTargets()
        {
            var targetNames = Enumerable.Range(1, 9)
                .Select(i => $"PS{i}")
                .ToList();

            return
                (from payee in Uow.Payees.GetAll()
                 join customer in Uow.Customers.GetAll() on payee.PayeeId equals customer.PayeeId
                 where targetNames.Contains(payee.PayeeName!)
                    && payee.PayeeType == "C"
                    && !payee.IsClosed
                 select new
                 {
                     payee.PayeeId,
                     payee.PayeeName,
                     customer.HasOwnList
                 })
                .ToList()
                .Select(row => new MgpPriceSheetTargetDto(
                    SheetNo: int.Parse(row.PayeeName![2..]),
                    CustomerName: row.PayeeName!,
                    PayeeId: row.PayeeId,
                    HasOwnList: row.HasOwnList))
                .OrderBy(row => row.SheetNo)
                .ToList();
        }
    }
}
