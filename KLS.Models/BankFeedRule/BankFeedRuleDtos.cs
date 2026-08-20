namespace KLS.Models
{
    public class BankFeedRuleListReq : PagingRequest
    {
        public bool? IsActive { get; set; }

        public long? BankFeedAccountId { get; set; }

        public string? Direction { get; set; }
    }

    public class BankFeedRuleDto
    {
        public int BankFeedRuleId { get; set; }

        public string RuleName { get; set; } = string.Empty;

        public long? BankFeedAccountId { get; set; }

        public string? BankFeedAccountName { get; set; }

        public string Direction { get; set; } = string.Empty;

        public string MatchMode { get; set; } = string.Empty;

        public int Priority { get; set; }

        public bool IsActive { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }

        public List<BankFeedRuleConditionDto> Conditions { get; set; } = new();

        public BankFeedRuleActionDto? Action { get; set; }
    }

    public class BankFeedRuleSaveReq
    {
        public int BankFeedRuleId { get; set; }

        public string RuleName { get; set; } = string.Empty;

        public long? BankFeedAccountId { get; set; }

        public string Direction { get; set; } = string.Empty;

        public string MatchMode { get; set; } = string.Empty;

        public int Priority { get; set; } = 100;

        public bool IsActive { get; set; } = true;

        public List<BankFeedRuleConditionDto> Conditions { get; set; } = new();

        public BankFeedRuleActionDto? Action { get; set; }
    }

    public class BankFeedRuleRecalculateReq
    {
        public List<long> BankFeedTransactionIds { get; set; } = new();
    }

    public class BankFeedRuleRecalculatePendingReq
    {
        public long? BankFeedAccountId { get; set; }
    }

    public class BankFeedRuleRecalculateRes
    {
        public int EvaluatedCount { get; set; }

        public int ExactMatchSkippedCount { get; set; }

        public int SuggestionCount { get; set; }

        public int ConflictCount { get; set; }

        public int MissingSetupCount { get; set; }
    }

    public class BankFeedRuleApplyRes
    {
        public long BankFeedTransactionId { get; set; }

        public long BankFeedRuleSuggestionId { get; set; }

        public string ActionType { get; set; } = string.Empty;

        public string BankFeedStatus { get; set; } = string.Empty;
    }

    public class BankFeedRuleConditionDto
    {
        public int BankFeedRuleConditionId { get; set; }

        public string ConditionType { get; set; } = string.Empty;

        public string ConditionValue { get; set; } = string.Empty;
    }

    public class BankFeedRuleActionDto
    {
        public int BankFeedRuleActionId { get; set; }

        public string ActionType { get; set; } = string.Empty;

        public int? PayeeId { get; set; }

        public string? PayeeName { get; set; }

        public int? AccountId { get; set; }

        public string? AccountName { get; set; }

        public int? TargetAccountId { get; set; }

        public string? TargetAccountName { get; set; }

        public string? MemoTemplate { get; set; }

        public bool AppendBankDescription { get; set; } = true;
    }

    public class BankFeedRuleSuggestionDto
    {
        public long BankFeedRuleSuggestionId { get; set; }

        public long BankFeedTransactionId { get; set; }

        public int BankFeedRuleId { get; set; }

        public string RuleName { get; set; } = string.Empty;

        public string SuggestionStatus { get; set; } = string.Empty;

        public bool IsPreferred { get; set; }

        public int Score { get; set; }

        public string? Reason { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? AppliedAt { get; set; }

        public DateTime? DismissedAt { get; set; }

        public BankFeedRuleActionDto? Action { get; set; }
    }
}
