using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [Route("api/admin/[controller]")]
    [Display(Name = "Trucks Management", GroupName = "Admin")]
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
    }
}
