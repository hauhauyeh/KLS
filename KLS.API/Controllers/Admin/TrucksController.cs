using KLS.API.Helpers;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Truck Management", GroupName = "Admin")]
    public class TrucksController : BaseController
    {
        #region --- Member(s) ---

        private readonly ITruckService _truckService;

        #endregion

        #region --- Constructor(s) ---

        public TrucksController(ITruckService truckService)
        {
            _truckService = truckService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Trucks")]
        public IActionResult List()
        {
            return Ok(_truckService.GetAllTrucks());
        }


        [HttpGet("Active")]
        public IActionResult GetActive()
        {
            return Ok(_truckService.GetActiveTrucks());
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            return Ok(_truckService.GetById(id));
        }


        [HttpPost]
        [DisplayName("Create Truck")]
        public IActionResult Create([FromBody] Truck truck)
        {
            if (_truckService.ExistsNumber(truck))
                return Conflict("TruckNumber already exists");

            return Ok(_truckService.CreateTruck(truck));
        }


        [HttpPut]
        [DisplayName("Update Truck")]
        public IActionResult Update([FromBody] Truck truck)
        {
            if (_truckService.ExistsNumber(truck))
                return Conflict("TruckNumber already exists");

            return Ok(_truckService.UpdateTruck(truck));
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Truck")]
        public IActionResult Delete(int id)
        {
            //if (_truckService.TermUsed(id))
            //    return Conflict("You can't delete. it is assigned to payee.");

            _truckService.DeleteTruck(id);

            return Ok();
        }

        #endregion
    }
}
