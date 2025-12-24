using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class TruckService : BaseService, ITruckService
    {
        public TruckService(IUnitOfWork uow) : base(uow)
        {

        }

        public IEnumerable<Truck> GetList()
        {
            return Uow.Trucks.GetAll().OrderBy(c => c.TruckNumber);
        }

        public IEnumerable<Truck> GetActive()
        {
            return Uow.Trucks.Find(c => c.Inactive == false).OrderBy(c => c.TruckNumber);
        }

        public Truck GetById(int id)
        {
            return Uow.Trucks.GetById(id);
        }

        public bool ExistsNumber(Truck truck)
        {
            return Uow.Trucks.Exists(c => c.TruckNumber.ToLower() == truck.TruckNumber.ToLower() && c.TruckId != truck.TruckId);
        }

        public Truck Create(Truck truck)
        {
            Uow.Trucks.Add(truck);
            Uow.Commit();

            return truck;
        }

        public Truck? Update(Truck truck)
        {
            var existing = GetById(truck.TruckId);

            if (existing != null)
            {
                existing.TruckNumber = truck.TruckNumber;
                existing.TruckName = truck.TruckName;
                existing.VinNumber = truck.VinNumber;
                existing.TruckTag = truck.TruckTag;
                existing.TruckYear = truck.TruckYear;
                existing.TruckModel = truck.TruckModel;
                existing.RegExpDate = truck.RegExpDate;
                existing.InsureProvider = truck.InsureProvider;
                existing.InsureCoverage = truck.InsureCoverage;
                existing.OwnLeaseRental = truck.OwnLeaseRental;
                existing.GPSNumber = truck.GPSNumber;
                existing.EPassNumber = truck.EPassNumber;
                existing.Notes = truck.Notes;
                existing.Inactive = truck.Inactive;
                existing.UpdatedAt = DateTime.UtcNow;

                Uow.Trucks.Update(existing);
                Uow.Commit();
            }

            return existing;
        }

        public void Delete(int truckId)
        {
            Uow.Trucks.RemoveById(truckId);
            Uow.Commit();
        }
    }
}
