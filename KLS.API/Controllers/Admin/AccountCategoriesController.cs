using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using KLS.Services;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Account Category Management", GroupName = "Admin")]
    public class AccountCategoriesController : BaseController
    {
        #region --- Member(s) ---

        private readonly IAccountCategoryService _accountCategoryService;

        #endregion

        #region --- Constructor(s) ---

        public AccountCategoriesController(IAccountCategoryService accountCategoryService)
        {
            _accountCategoryService = accountCategoryService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet("FlatTree")]
        public IActionResult GetFlatTree()
        {
            return Ok(_accountCategoryService.GetFlatTree());
        }


        [HttpGet("RecursiveTree")]
        public IActionResult GetRecursiveTree()
        {
            return Ok(_accountCategoryService.GetRecursiveTree());
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            return Ok(_accountCategoryService.GetById(id));
        }


        [HttpPost]
        public IActionResult Create(AccountCategory category)
        {
            try
            {
                var result = _accountCategoryService.Create(category);

                return Ok(result);
            }
            catch (Exception ex)
            {
                return BadRequest(ex.Message);
            }
        }


        [HttpPut]
        public IActionResult Update(AccountCategory category)
        {
            try
            {
                var result = _accountCategoryService.Update(category);

                return Ok(result);
            }
            catch (Exception ex)
            {
                return BadRequest(ex.Message);
            }

        }


        [HttpDelete("{id}")]
        public IActionResult Delete(int id)
        {
            try
            {
                _accountCategoryService.Delete(id);
                return Ok();
            }
            catch (Exception ex)
            {
                return BadRequest(ex.Message);
            }
        }


        [HttpPost("Reorder")]
        public IActionResult ReorderNode(AccountNodeReorderReq dto)
        {
            try
            {
                _accountCategoryService.ReorderNode(dto);
                return Ok();
            }
            catch (Exception ex)
            {
                return BadRequest(ex.Message);
            }
        }


        [HttpPost("MoveAccount")]
        public IActionResult MoveAccount(AccountMoveReq dto)
        {
            try
            {
                _accountCategoryService.MoveAccount(dto);
                return Ok();
            }
            catch (Exception ex)
            {
                return BadRequest(ex.Message);
            }
        }


        #endregion
    }
}
