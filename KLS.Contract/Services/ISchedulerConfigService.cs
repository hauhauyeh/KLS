using KLS.Models;

namespace KLS.Contract.Services
{
    public interface ISchedulerConfigService
    {
        IEnumerable<SchedulerConfig> GetList();

        SchedulerConfig? GetById(int id);

        SchedulerConfig? Update(SchedulerConfig schedulerConfig);
    }
}
