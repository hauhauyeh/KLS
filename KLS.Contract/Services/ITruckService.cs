using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ITruckService
    {
        IEnumerable<Truck> GetList();

        IEnumerable<Truck> GetActive();

        Truck GetById(int id);

        bool ExistsNumber(Truck truck);

        Truck Create(Truck truck);

        Truck? Update(Truck truck);

        void Delete(int truckId);
    }
}
