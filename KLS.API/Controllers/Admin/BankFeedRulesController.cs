using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Bank Feed Rule Management", GroupName = "Accounting")]
    public class BankFeedRulesController : BaseController
    {
        private readonly IBankFeedRuleService _bankFeedRuleService;

        public BankFeedRulesController(IBankFeedRuleService bankFeedRuleService)
        {
            _bankFeedRuleService = bankFeedRuleService;
        }

        [HttpGet]
        [DisplayName("List Bank Feed Rules")]
        [PermissionKey("Accounting.BankFeed.Rule.List")]
        public IActionResult List([FromQuery] BankFeedRuleListReq req)
        {
            return Ok(_bankFeedRuleService.GetPagedList(req));
        }

        [HttpGet("{id}")]
        [DisplayName("Get Bank Feed Rule")]
        [PermissionKey("Accounting.BankFeed.Rule.List")]
        public IActionResult GetById(int id)
        {
            return Ok(_bankFeedRuleService.GetById(id));
        }

        [HttpPost]
        [DisplayName("Create Bank Feed Rule")]
        [PermissionKey("Accounting.BankFeed.Rule.Manage")]
        public IActionResult Create([FromBody] BankFeedRuleSaveReq req)
        {
            req.BankFeedRuleId = 0;
            return Ok(_bankFeedRuleService.Save(req));
        }

        [HttpPut]
        [DisplayName("Update Bank Feed Rule")]
        [PermissionKey("Accounting.BankFeed.Rule.Manage")]
        public IActionResult Update([FromBody] BankFeedRuleSaveReq req)
        {
            return Ok(_bankFeedRuleService.Save(req));
        }

        [HttpPost("NextOrder")]
        [DisplayName("Get Next Bank Feed Rule Order")]
        [PermissionKey("Accounting.BankFeed.Rule.Manage")]
        public IActionResult NextOrder([FromBody] BankFeedRuleNextOrderReq req)
        {
            return Ok(_bankFeedRuleService.GetNextOrder(req));
        }

        [HttpPost("Reorder")]
        [DisplayName("Reorder Bank Feed Rules")]
        [PermissionKey("Accounting.BankFeed.Rule.Manage")]
        public IActionResult Reorder([FromBody] BankFeedRuleReorderReq req)
        {
            _bankFeedRuleService.Reorder(req);
            return Ok();
        }

        [HttpPost("{id}/Deactivate")]
        [DisplayName("Deactivate Bank Feed Rule")]
        [PermissionKey("Accounting.BankFeed.Rule.Manage")]
        public IActionResult Deactivate(int id)
        {
            _bankFeedRuleService.Deactivate(id);
            return Ok();
        }

        [HttpDelete("{id}")]
        [DisplayName("Delete Bank Feed Rule")]
        [PermissionKey("Accounting.BankFeed.Rule.Manage")]
        public IActionResult Delete(int id)
        {
            _bankFeedRuleService.Delete(id);
            return Ok();
        }
    }
}
