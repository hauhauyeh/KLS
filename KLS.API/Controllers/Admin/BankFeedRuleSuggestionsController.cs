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
    [Display(Name = "Bank Feed Rule Suggestion Management", GroupName = "Accounting")]
    public class BankFeedRuleSuggestionsController : BaseController
    {
        private readonly IBankFeedRuleService _bankFeedRuleService;

        public BankFeedRuleSuggestionsController(IBankFeedRuleService bankFeedRuleService)
        {
            _bankFeedRuleService = bankFeedRuleService;
        }

        [HttpGet("ByTransaction/{bankFeedTransactionId}")]
        [DisplayName("List Bank Feed Rule Suggestions")]
        [PermissionKey("Accounting.BankFeed.Rule.List")]
        public IActionResult ByTransaction(long bankFeedTransactionId)
        {
            return Ok(_bankFeedRuleService.GetSuggestions(bankFeedTransactionId));
        }

        [HttpPost("{bankFeedRuleSuggestionId:long}/Apply")]
        [DisplayName("Apply Bank Feed Rule Suggestion")]
        [PermissionKey("Accounting.BankFeed.Match")]
        public IActionResult Apply(long bankFeedRuleSuggestionId)
        {
            return Ok(_bankFeedRuleService.Apply(bankFeedRuleSuggestionId));
        }

        [HttpPost("Recalculate")]
        [DisplayName("Recalculate Bank Feed Rule Suggestions")]
        [PermissionKey("Accounting.BankFeed.Rule.Recalculate")]
        public IActionResult Recalculate([FromBody] BankFeedRuleRecalculateReq req)
        {
            return Ok(_bankFeedRuleService.Recalculate(req));
        }

        [HttpPost("RecalculatePending")]
        [DisplayName("Recalculate Pending Bank Feed Rule Suggestions")]
        [PermissionKey("Accounting.BankFeed.Rule.Recalculate")]
        public IActionResult RecalculatePending([FromBody] BankFeedRuleRecalculatePendingReq req)
        {
            return Ok(_bankFeedRuleService.RecalculatePending(req));
        }
    }
}
