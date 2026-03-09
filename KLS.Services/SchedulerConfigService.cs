using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;

namespace KLS.Services
{
    public class SchedulerConfigService : BaseService, ISchedulerConfigService
    {
        public SchedulerConfigService(IUnitOfWork uow) : base(uow)
        {
        }

        public IEnumerable<SchedulerConfig> GetList()
        {
            return Uow.SchedulerConfigs.GetAll().ToList();
        }

        public SchedulerConfig? GetById(int id)
        {
            return Uow.SchedulerConfigs.GetById(id);
        }

        public SchedulerConfig? Update(SchedulerConfig schedulerConfig)
        {
            var existing = GetById(schedulerConfig.Id);

            if (existing != null)
            {
                existing.JobDescription = schedulerConfig.JobDescription;
                existing.Frequency = schedulerConfig.Frequency;
                existing.RunTime = schedulerConfig.RunTime;
                existing.DayOfWeek = schedulerConfig.DayOfWeek;
                existing.DayOfMonth = schedulerConfig.DayOfMonth;
                existing.IsEnabled = schedulerConfig.IsEnabled;
                existing.UpdatedAt = DateTime.UtcNow;

                Uow.SchedulerConfigs.Update(existing);
                Uow.Commit();
            }

            return existing;
        }
    }
}
