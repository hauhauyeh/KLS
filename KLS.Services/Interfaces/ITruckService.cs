using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface ITruckService
    {
        IQueryable<Truck> GetAllTrucks();

        ICollection<Truck> GetActiveTrucks();

        Truck GetById(int id);

        bool ExistsNumber(Truck truck);

        Truck CreateTruck(Truck truck);

        Truck? UpdateTruck(Truck truck);

        void DeleteTruck(int truckId);
    }
}
