using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Common;
using KLS.Models;
using System.Text.RegularExpressions;

namespace KLS.Services
{
    public class BankFeedRuleService : BaseService, IBankFeedRuleService
    {
        private static readonly HashSet<string> Directions = new(StringComparer.OrdinalIgnoreCase)
        {
            "MoneyIn",
            "MoneyOut"
        };

        private static readonly HashSet<string> MatchModes = new(StringComparer.OrdinalIgnoreCase)
        {
            "All",
            "AnyTextWithDirection"
        };

        private static readonly HashSet<string> ConditionTypes = new(StringComparer.OrdinalIgnoreCase)
        {
            "DescriptionContains",
            "DescriptionEquals"
        };

        private static readonly HashSet<string> ActionTypes = new(StringComparer.OrdinalIgnoreCase)
        {
            "CreateMoneyOutExpense",
            "CreateMoneyInDeposit",
            "CreateTransfer",
            "Exclude"
        };

        private const int BulkApplyMaxRows = 100;

        public BankFeedRuleService(IUnitOfWork uow) : base(uow)
        {
        }

        public PagingResponse<BankFeedRuleDto> GetPagedList(BankFeedRuleListReq req)
        {
            req ??= new BankFeedRuleListReq();
            var query = Uow.BankFeedRules.GetRulesWithChildren();

            if (req.IsActive.HasValue)
            {
                query = query.Where(c => c.IsActive == req.IsActive.Value);
            }

            if (req.BankFeedAccountId.HasValue)
            {
                query = query.Where(c => c.BankFeedAccountId == req.BankFeedAccountId.Value);
            }

            if (!string.IsNullOrWhiteSpace(req.Direction))
            {
                query = query.Where(c => c.Direction == req.Direction);
            }

            if (!string.IsNullOrWhiteSpace(req.Search))
            {
                var search = req.Search.Trim().ToLower();
                query = query.Where(c => c.RuleName.ToLower().Contains(search)
                    || c.Conditions.Any(d => d.ConditionValue.ToLower().Contains(search)));
            }

            var totalRecords = query.Count();
            var rules = query
                .OrderBy(c => c.Priority)
                .ThenBy(c => c.RuleName)
                .Skip((req.Pageno - 1) * req.Pagesize)
                .Take(req.Pagesize)
                .ToList();

            return new PagingResponse<BankFeedRuleDto>(totalRecords, req.Pageno, req.Pagesize)
            {
                RowData = MapRules(rules)
            };
        }

        public BankFeedRuleDto? GetById(int bankFeedRuleId)
        {
            var rule = Uow.BankFeedRules.GetRulesWithChildren()
                .FirstOrDefault(c => c.BankFeedRuleId == bankFeedRuleId);

            return rule == null ? null : MapRules(new[] { rule }).Single();
        }

        public BankFeedRuleDto Save(BankFeedRuleSaveReq req)
        {
            Validate(req);

            BankFeedRule? savedRule = null;
            Uow.ExecuteInTransaction(() =>
            {
                BankFeedRule rule;
                if (req.BankFeedRuleId > 0)
                {
                    rule = Uow.BankFeedRules.GetRuleWithChildren(req.BankFeedRuleId)
                        ?? throw new ArgumentException("Bank feed rule was not found.");

                    rule.RuleName = req.RuleName.Trim();
                    rule.BankFeedAccountId = req.BankFeedAccountId;
                    rule.Direction = Canonical(Directions, req.Direction);
                    rule.MatchMode = Canonical(MatchModes, req.MatchMode);
                    rule.Priority = req.Priority;
                    rule.IsActive = req.IsActive;
                    rule.UpdatedAt = DateTime.UtcNow;

                    Uow.BankFeedRules.RemoveRuleChildren(rule);
                    rule.Conditions.Clear();
                    rule.Action = null;
                    Uow.Commit();
                }
                else
                {
                    rule = new BankFeedRule();
                    Uow.BankFeedRules.Add(rule);
                    rule.RuleName = req.RuleName.Trim();
                    rule.BankFeedAccountId = req.BankFeedAccountId;
                    rule.Direction = Canonical(Directions, req.Direction);
                    rule.MatchMode = Canonical(MatchModes, req.MatchMode);
                    rule.Priority = req.Priority;
                    rule.IsActive = req.IsActive;
                }

                foreach (var condition in req.Conditions)
                {
                    rule.Conditions.Add(new BankFeedRuleCondition
                    {
                        ConditionType = Canonical(ConditionTypes, condition.ConditionType),
                        ConditionValue = condition.ConditionValue.Trim()
                    });
                }

                rule.Action = new BankFeedRuleAction
                {
                    ActionType = Canonical(ActionTypes, req.Action!.ActionType),
                    PayeeId = req.Action.PayeeId,
                    AccountId = req.Action.AccountId,
                    TargetAccountId = req.Action.TargetAccountId,
                    MemoTemplate = string.IsNullOrWhiteSpace(req.Action.MemoTemplate) ? null : req.Action.MemoTemplate.Trim(),
                    AppendBankDescription = req.Action.AppendBankDescription,
                    UpdatedAt = req.BankFeedRuleId > 0 ? DateTime.UtcNow : null
                };

                Uow.Commit();
                savedRule = rule;
            });

            return GetById(savedRule!.BankFeedRuleId)!;
        }

        public BankFeedRuleNextOrderRes GetNextOrder(BankFeedRuleNextOrderReq req)
        {
            req ??= new BankFeedRuleNextOrderReq();

            if (!Directions.Contains(req.Direction))
                throw new ArgumentException("Rule direction is invalid.");

            var direction = Canonical(Directions, req.Direction);
            var maxPriority = Uow.BankFeedRules.GetRulesWithChildren()
                .Where(c => c.IsActive && c.Direction == direction)
                .Select(c => (int?)c.Priority)
                .Max() ?? 0;

            return new BankFeedRuleNextOrderRes
            {
                Priority = maxPriority + 1
            };
        }

        public void Reorder(BankFeedRuleReorderReq req)
        {
            req ??= new BankFeedRuleReorderReq();

            if (!Directions.Contains(req.Direction))
                throw new ArgumentException("Rule direction is invalid.");

            if (req.RuleIds == null)
                throw new ArgumentException("Rule order is required.");

            var direction = Canonical(Directions, req.Direction);
            var submittedIds = req.RuleIds.ToList();
            var distinctSubmittedIds = submittedIds.Distinct().ToList();

            if (submittedIds.Count != distinctSubmittedIds.Count)
                throw new ArgumentException("Duplicate rules are not allowed in reorder.");

            Uow.ExecuteInTransaction(() =>
            {
                var activeRules = Uow.BankFeedRules.Find(c => c.IsActive && c.Direction == direction)
                    .ToList();
                var activeIds = activeRules
                    .Select(c => c.BankFeedRuleId)
                    .OrderBy(c => c)
                    .ToList();
                var submittedSetIds = distinctSubmittedIds
                    .OrderBy(c => c)
                    .ToList();

                if (activeIds.Count != submittedSetIds.Count || !activeIds.SequenceEqual(submittedSetIds))
                    throw new ArgumentException("Submitted rule order must match all active rules for this direction.");

                var ruleMap = activeRules.ToDictionary(c => c.BankFeedRuleId);
                var updatedAt = DateTime.UtcNow;

                for (var index = 0; index < submittedIds.Count; index++)
                {
                    var rule = ruleMap[submittedIds[index]];
                    rule.Priority = index + 1;
                    rule.UpdatedAt = updatedAt;
                }

                Uow.Commit();
            });
        }

        public void Deactivate(int bankFeedRuleId)
        {
            var rule = Uow.BankFeedRules.GetRuleWithChildren(bankFeedRuleId)
                ?? throw new ArgumentException("Bank feed rule was not found.");

            rule.IsActive = false;
            rule.UpdatedAt = DateTime.UtcNow;
            Uow.Commit();
        }

        public void Delete(int bankFeedRuleId)
        {
            var rule = Uow.BankFeedRules.GetRuleWithChildren(bankFeedRuleId)
                ?? throw new ArgumentException("Bank feed rule was not found.");

            if (Uow.BankFeedRuleSuggestions.Exists(c => c.BankFeedRuleId == bankFeedRuleId))
            {
                rule.IsActive = false;
                rule.UpdatedAt = DateTime.UtcNow;
            }
            else
            {
                Uow.BankFeedRules.RemoveRule(rule);
            }

            Uow.Commit();
        }

        public BankFeedRuleRecalculateRes Recalculate(BankFeedRuleRecalculateReq req)
        {
            req ??= new BankFeedRuleRecalculateReq();
            var transactionIds = (req.BankFeedTransactionIds ?? new List<long>())
                .Where(c => c > 0)
                .Distinct()
                .ToList();

            if (!transactionIds.Any())
                throw new ArgumentException("At least one bank feed transaction is required.");

            var transactions = Uow.BankFeedTransactions.Find(c => transactionIds.Contains(c.BankFeedTransactionId))
                .ToList();
            var activeRules = Uow.BankFeedRules.GetRulesWithChildren()
                .Where(c => c.IsActive)
                .OrderBy(c => c.Priority)
                .ThenBy(c => c.BankFeedRuleId)
                .ToList();
            var result = new BankFeedRuleRecalculateRes();

            Uow.ExecuteInTransaction(() =>
            {
                ExpireActiveSuggestions(transactionIds);

                foreach (var transaction in transactions)
                {
                    if (transaction.Status != "Pending" || transaction.Amount == 0)
                        continue;

                    result.EvaluatedCount++;

                    if (HasSafeExactMatch(transaction))
                    {
                        result.ExactMatchSkippedCount++;
                        continue;
                    }

                    var matches = activeRules
                        .Where(rule => RuleMatches(rule, transaction))
                        .Select(rule => new RuleEvaluation(rule, GetSetupStatus(rule, transaction)))
                        .ToList();

                    if (!matches.Any())
                        continue;

                    AddSuggestions(transaction.BankFeedTransactionId, matches, result);
                }

                Uow.Commit();
            });

            return result;
        }

        public BankFeedRuleRecalculateRes RecalculatePending(BankFeedRuleRecalculatePendingReq req)
        {
            req ??= new BankFeedRuleRecalculatePendingReq();

            if (req.BankFeedAccountId.HasValue && !Uow.BankFeedAccounts.Exists(c => c.BankFeedAccountId == req.BankFeedAccountId.Value))
                throw new ArgumentException("Bank feed account was not found.");

            var query = Uow.BankFeedTransactions.Find(c => c.Status == "Pending");
            if (req.BankFeedAccountId.HasValue)
            {
                query = query.Where(c => c.BankFeedAccountId == req.BankFeedAccountId.Value);
            }

            var transactionIds = query
                .Select(c => c.BankFeedTransactionId)
                .ToList();

            if (!transactionIds.Any())
                return new BankFeedRuleRecalculateRes();

            return Recalculate(new BankFeedRuleRecalculateReq
            {
                BankFeedTransactionIds = transactionIds
            });
        }

        public List<BankFeedRuleSuggestionDto> GetSuggestions(long bankFeedTransactionId)
        {
            var suggestions = Uow.BankFeedRuleSuggestions.GetSuggestionsWithRule()
                .Where(c => c.BankFeedTransactionId == bankFeedTransactionId)
                .OrderByDescending(c => c.IsPreferred)
                .ThenByDescending(c => c.Score)
                .ThenBy(c => c.BankFeedRuleSuggestionId)
                .ToList();

            var rules = suggestions
                .Where(c => c.Rule != null)
                .Select(c => c.Rule!)
                .ToList();

            var mappedRules = MapRules(rules)
                .ToDictionary(c => c.BankFeedRuleId);

            return suggestions.Select(c =>
            {
                mappedRules.TryGetValue(c.BankFeedRuleId, out var rule);
                return new BankFeedRuleSuggestionDto
                {
                    BankFeedRuleSuggestionId = c.BankFeedRuleSuggestionId,
                    BankFeedTransactionId = c.BankFeedTransactionId,
                    BankFeedRuleId = c.BankFeedRuleId,
                    RuleName = rule?.RuleName ?? string.Empty,
                    SuggestionStatus = c.SuggestionStatus,
                    IsPreferred = c.IsPreferred,
                    Score = c.Score,
                    Reason = c.Reason,
                    CreatedAt = c.CreatedAt,
                    AppliedAt = c.AppliedAt,
                    DismissedAt = c.DismissedAt,
                    Action = rule?.Action
                };
            }).ToList();
        }

        public BankFeedRuleApplyRes Apply(long bankFeedRuleSuggestionId)
        {
            BankFeedRuleApplyRes? result = null;

            Uow.ExecuteInTransaction(() =>
            {
                var suggestion = Uow.BankFeedRuleSuggestions.Find(c => c.BankFeedRuleSuggestionId == bankFeedRuleSuggestionId)
                    .SingleOrDefault()
                    ?? throw new ArgumentException("Bank feed rule suggestion was not found.");

                if (suggestion.SuggestionStatus != "Suggested")
                    throw new ArgumentException("Only suggested rule actions can be applied.");

                var rule = Uow.BankFeedRules.GetRuleWithChildren(suggestion.BankFeedRuleId)
                    ?? throw new ArgumentException("Bank feed rule was not found.");

                if (!rule.IsActive)
                    throw new ArgumentException("Bank feed rule is inactive.");

                if (rule.Action == null)
                    throw new ArgumentException("Bank feed rule action is missing.");

                if (DirectionActionError(rule.Direction, rule.Action.ActionType) != null)
                    throw new ArgumentException("Bank feed rule action is not valid for its direction.");

                var transaction = Uow.BankFeedTransactions.GetByLongId(suggestion.BankFeedTransactionId)
                    ?? throw new ArgumentException("Bank feed transaction was not found.");

                if (transaction.Status != "Pending")
                    throw new ArgumentException("Only pending bank feed transactions can apply rule suggestions.");

                if (!RuleMatches(rule, transaction))
                    throw new ArgumentException("Bank feed rule no longer matches this transaction.");

                if (rule.Action.ActionType == "Exclude")
                {
                    transaction.Status = "Excluded";
                    transaction.ExcludeReason = $"Rule: {rule.RuleName}";
                }
                else if (rule.Action.ActionType == "CreateMoneyOutExpense")
                {
                    ApplyMoneyOutExpense(rule, transaction);
                }
                else if (rule.Action.ActionType == "CreateMoneyInDeposit")
                {
                    ApplyMoneyInDeposit(rule, transaction);
                }
                else if (rule.Action.ActionType == "CreateTransfer")
                {
                    ApplyTransfer(rule, transaction);
                }
                else
                {
                    throw new ArgumentException("This rule action is not supported yet.");
                }

                suggestion.SuggestionStatus = "Applied";
                suggestion.AppliedAt = DateTime.UtcNow;
                suggestion.AppliedBy = UserContext.EmpId;

                ExpireOtherActiveSuggestions(transaction.BankFeedTransactionId, suggestion.BankFeedRuleSuggestionId);

                Uow.Commit();

                result = new BankFeedRuleApplyRes
                {
                    BankFeedTransactionId = transaction.BankFeedTransactionId,
                    BankFeedRuleSuggestionId = suggestion.BankFeedRuleSuggestionId,
                    ActionType = rule.Action.ActionType,
                    BankFeedStatus = rule.Action.ActionType == "Exclude" ? "Excluded" : "Matched"
                };
            });

            return result!;
        }

        public BankFeedRuleBulkApplyRes ApplyBulk(BankFeedBulkActionReq req)
        {
            if (req?.BankFeedTransactionIds == null || !req.BankFeedTransactionIds.Any())
                throw new ArgumentException("Please select at least one transaction.");

            var ids = req.BankFeedTransactionIds
                .Where(c => c > 0)
                .Distinct()
                .ToList();

            if (!ids.Any())
                throw new ArgumentException("Please select at least one transaction.");

            if (ids.Count > BulkApplyMaxRows)
                throw new ArgumentException($"Rule bulk apply supports up to {BulkApplyMaxRows} selected transactions.");

            var result = new BankFeedRuleBulkApplyRes
            {
                RequestedCount = ids.Count
            };

            var transactions = Uow.BankFeedTransactions
                .Find(c => ids.Contains(c.BankFeedTransactionId))
                .ToDictionary(c => c.BankFeedTransactionId);

            var suggestions = Uow.BankFeedRuleSuggestions.GetSuggestionsWithRule()
                .Where(c => ids.Contains(c.BankFeedTransactionId)
                    && (c.SuggestionStatus == "Suggested"
                        || c.SuggestionStatus == "Conflict"
                        || c.SuggestionStatus == "MissingSetup"))
                .ToList()
                .GroupBy(c => c.BankFeedTransactionId)
                .ToDictionary(c => c.Key, c => c.ToList());

            foreach (var id in ids)
            {
                var detail = BuildBulkApplyCandidate(id, transactions, suggestions);
                result.Details.Add(detail);

                if (detail.ResultStatus == "Skipped")
                {
                    result.SkippedCount++;
                    continue;
                }

                result.EligibleCount++;

                try
                {
                    Apply(detail.BankFeedRuleSuggestionId!.Value);
                    detail.ResultStatus = "Applied";
                    detail.Reason = "Applied.";
                    result.AppliedCount++;
                }
                catch (Exception ex)
                {
                    detail.ResultStatus = "Failed";
                    detail.Reason = ex.Message;
                    result.FailedCount++;
                }
            }

            return result;
        }

        private static BankFeedRuleBulkApplyDetail BuildBulkApplyCandidate(
            long bankFeedTransactionId,
            Dictionary<long, BankFeedTransaction> transactions,
            Dictionary<long, List<BankFeedRuleSuggestion>> suggestions)
        {
            var detail = new BankFeedRuleBulkApplyDetail
            {
                BankFeedTransactionId = bankFeedTransactionId
            };

            if (!transactions.TryGetValue(bankFeedTransactionId, out var transaction))
                return Skip(detail, "Bank feed transaction was not found.");

            if (transaction.Status != "Pending")
                return Skip(detail, "Only pending bank feed transactions can apply rule suggestions.");

            if (!suggestions.TryGetValue(bankFeedTransactionId, out var rowSuggestions) || !rowSuggestions.Any())
                return Skip(detail, "No active rule suggestion found.");

            var preferred = rowSuggestions
                .Where(c => c.SuggestionStatus == "Suggested" && c.IsPreferred)
                .ToList();

            if (preferred.Count == 0)
            {
                if (rowSuggestions.Any(c => c.SuggestionStatus == "Conflict"))
                    return Skip(detail, "Rule suggestion has a conflict.");

                if (rowSuggestions.Any(c => c.SuggestionStatus == "MissingSetup"))
                    return Skip(detail, "Rule suggestion setup is missing or inactive.");

                if (rowSuggestions.Any(c => c.SuggestionStatus == "Suggested"))
                    return Skip(detail, "No preferred rule suggestion found.");

                return Skip(detail, "No applyable rule suggestion found.");
            }

            if (preferred.Count > 1)
                return Skip(detail, "Multiple preferred rule suggestions found.");

            var suggestion = preferred.Single();
            var actionType = suggestion.Rule?.Action?.ActionType;
            detail.BankFeedRuleSuggestionId = suggestion.BankFeedRuleSuggestionId;
            detail.RuleName = suggestion.Rule?.RuleName;
            detail.ActionType = actionType;

            if (string.IsNullOrWhiteSpace(actionType) || !ActionTypes.Contains(actionType))
                return Skip(detail, "Rule action is not supported.");

            detail.ResultStatus = "Eligible";
            detail.Reason = "Eligible.";
            return detail;
        }

        private static BankFeedRuleBulkApplyDetail Skip(BankFeedRuleBulkApplyDetail detail, string reason)
        {
            detail.ResultStatus = "Skipped";
            detail.Reason = reason;
            return detail;
        }

        private void ApplyMoneyOutExpense(BankFeedRule rule, BankFeedTransaction transaction)
        {
            var action = rule.Action!;
            if (transaction.Amount >= 0)
                throw new ArgumentException("Only money-out bank feed transactions can create an expense.");

            if (!action.PayeeId.HasValue)
                throw new ArgumentException("Rule action vendor is required for money-out expense apply.");

            if (!action.AccountId.HasValue)
                throw new ArgumentException("Rule action account is required for money-out expense apply.");

            if (!Uow.Payees.Exists(c => c.PayeeId == action.PayeeId.Value && !c.IsClosed))
                throw new ArgumentException("Rule action vendor is missing or inactive.");

            var actionAccount = Uow.Accounts.Find(c => c.AccountId == action.AccountId.Value && !c.Inactive)
                .SingleOrDefault()
                ?? throw new ArgumentException("Rule action account is missing or inactive.");

            if (actionAccount.AccountCode == "@AP")
                throw new ArgumentException("Rule action account cannot be Accounts Payable.");

            var bankFeedAccount = Uow.BankFeedAccounts.GetByLongId(transaction.BankFeedAccountId)
                ?? throw new ArgumentException("Bank feed account was not found.");

            if (bankFeedAccount.AccountId == action.AccountId.Value)
                throw new ArgumentException("Rule action account cannot be the bank account.");

            var resolvingLine = new BankFeedResolvingLineReq
            {
                PayeeId = action.PayeeId.Value,
                AccountId = action.AccountId.Value,
                Amount = Math.Abs(transaction.Amount),
                Notes = string.IsNullOrWhiteSpace(action.MemoTemplate) ? rule.RuleName : action.MemoTemplate.Trim()
            };

            var req = new BankFeedCreateVendorPaymentReq
            {
                BankFeedTransactionId = transaction.BankFeedTransactionId,
                PaymentMethod = "ACH",
                ReferenceId = transaction.ReferenceNo ?? transaction.CheckNumber,
                AppendBankDescription = action.AppendBankDescription,
                ResolvingLines = new List<BankFeedResolvingLineReq> { resolvingLine }
            };

            var resolvingJson = Newtonsoft.Json.JsonConvert.SerializeObject(
                req.ResolvingLines.Select(l => new { l.PayeeId, l.AccountId, l.Amount, l.Notes }));

            Uow.BankFeedTransactions.CreateVendorPayment(req, null, resolvingJson, UserContext.EmpId);
        }

        private void ApplyMoneyInDeposit(BankFeedRule rule, BankFeedTransaction transaction)
        {
            var action = rule.Action!;
            if (transaction.Amount <= 0)
                throw new ArgumentException("Only money-in bank feed transactions can create a deposit.");

            if (!action.AccountId.HasValue)
                throw new ArgumentException("Rule action account is required for money-in deposit apply.");

            if (action.PayeeId.HasValue && !Uow.Payees.Exists(c => c.PayeeId == action.PayeeId.Value && !c.IsClosed))
                throw new ArgumentException("Rule action payee is missing or inactive.");

            var actionAccount = Uow.Accounts.Find(c => c.AccountId == action.AccountId.Value && !c.Inactive)
                .SingleOrDefault()
                ?? throw new ArgumentException("Rule action account is missing or inactive.");

            if (IsBlockedMoneyInAccount(actionAccount))
                throw new ArgumentException("Rule action account cannot be Undeposited Funds, Accounts Receivable, or Accounts Payable.");

            var bankFeedAccount = Uow.BankFeedAccounts.GetByLongId(transaction.BankFeedAccountId)
                ?? throw new ArgumentException("Bank feed account was not found.");

            var sourceAccount = Uow.Accounts.Find(c => c.AccountId == bankFeedAccount.AccountId && !c.Inactive)
                .SingleOrDefault()
                ?? throw new ArgumentException("Bank feed mapped account is missing or inactive.");

            if (!sourceAccount.IsAccountDebit)
                throw new ArgumentException("Rule money-in only supports debit-side bank or cash accounts.");

            if (bankFeedAccount.AccountId == action.AccountId.Value)
                throw new ArgumentException("Rule action account cannot be the bank account.");

            var req = new BankFeedCreateRuleMoneyInReq
            {
                BankFeedTransactionId = transaction.BankFeedTransactionId,
                PayeeId = action.PayeeId,
                AccountId = action.AccountId.Value,
                ReferenceId = transaction.ReferenceNo ?? transaction.CheckNumber,
                Notes = string.IsNullOrWhiteSpace(action.MemoTemplate) ? rule.RuleName : action.MemoTemplate.Trim(),
                AppendBankDescription = action.AppendBankDescription
            };

            Uow.BankFeedTransactions.CreateRuleMoneyIn(req, UserContext.EmpId);
        }

        private void ApplyTransfer(BankFeedRule rule, BankFeedTransaction transaction)
        {
            var action = rule.Action!;
            if (transaction.Amount == 0)
                throw new ArgumentException("Zero amount bank feed transactions cannot create a transfer.");

            if (!action.TargetAccountId.HasValue)
                throw new ArgumentException("Rule transfer target account is required.");

            var bankFeedAccount = Uow.BankFeedAccounts.GetByLongId(transaction.BankFeedAccountId)
                ?? throw new ArgumentException("Bank feed account was not found.");

            var sourceAccount = Uow.Accounts.Find(c => c.AccountId == bankFeedAccount.AccountId && !c.Inactive)
                .SingleOrDefault()
                ?? throw new ArgumentException("Bank feed mapped account is missing or inactive.");

            if (!IsTransferSourceAccount(sourceAccount))
                throw new ArgumentException("Rule transfer only supports bank feed rows mapped to a bank account.");

            var targetAccount = Uow.Accounts.Find(c => c.AccountId == action.TargetAccountId.Value && !c.Inactive)
                .SingleOrDefault()
                ?? throw new ArgumentException("Rule transfer target account is missing or inactive.");

            if (!IsTransferTargetAccount(targetAccount))
                throw new ArgumentException("Rule transfer target account must be Bank or Cash.");

            if (sourceAccount.AccountId == targetAccount.AccountId)
                throw new ArgumentException("Rule transfer target account cannot be the same as the bank feed account.");

            var req = new BankFeedCreateTransferReq
            {
                BankFeedTransactionId = transaction.BankFeedTransactionId,
                TargetAccountId = targetAccount.AccountId,
                ReferenceId = transaction.ReferenceNo ?? transaction.CheckNumber,
                Notes = string.IsNullOrWhiteSpace(action.MemoTemplate) ? rule.RuleName : action.MemoTemplate.Trim(),
                AppendBankDescription = action.AppendBankDescription
            };

            Uow.BankFeedTransactions.CreateTransfer(req, UserContext.EmpId);
        }

        private void ExpireActiveSuggestions(List<long> bankFeedTransactionIds)
        {
            var suggestions = Uow.BankFeedRuleSuggestions.GetActiveSuggestions(bankFeedTransactionIds).ToList();
            foreach (var suggestion in suggestions)
            {
                suggestion.SuggestionStatus = "Expired";
            }
        }

        private void ExpireOtherActiveSuggestions(long bankFeedTransactionId, long appliedSuggestionId)
        {
            var suggestions = Uow.BankFeedRuleSuggestions.GetActiveSuggestions(new[] { bankFeedTransactionId })
                .Where(c => c.BankFeedRuleSuggestionId != appliedSuggestionId)
                .ToList();

            foreach (var suggestion in suggestions)
            {
                suggestion.SuggestionStatus = "Expired";
            }
        }

        private void AddSuggestions(long bankFeedTransactionId, List<RuleEvaluation> matches, BankFeedRuleRecalculateRes result)
        {
            var bestPriority = matches.Min(c => c.Rule.Priority);
            var topMatches = matches.Where(c => c.Rule.Priority == bestPriority).ToList();
            var hasConflict = topMatches.Count > 1;
            var preferredRuleId = hasConflict ? (int?)null : topMatches.Single().Rule.BankFeedRuleId;

            foreach (var match in matches)
            {
                var isTop = match.Rule.Priority == bestPriority;
                var status = hasConflict && isTop ? "Conflict" : match.SetupStatus;
                var isPreferred = preferredRuleId == match.Rule.BankFeedRuleId
                    && (status == "Suggested" || status == "MissingSetup");

                Uow.BankFeedRuleSuggestions.Add(new BankFeedRuleSuggestion
                {
                    BankFeedTransactionId = bankFeedTransactionId,
                    BankFeedRuleId = match.Rule.BankFeedRuleId,
                    SuggestionStatus = status,
                    IsPreferred = isPreferred,
                    Score = Math.Max(0, 10000 - match.Rule.Priority),
                    Reason = BuildReason(match.Rule, status)
                });

                result.SuggestionCount++;
                if (status == "Conflict")
                    result.ConflictCount++;
                if (status == "MissingSetup")
                    result.MissingSetupCount++;
            }
        }

        private bool HasSafeExactMatch(BankFeedTransaction transaction)
        {
            var strictMatches = Uow.BankFeedTransactions.GetMatchCandidates(transaction.BankFeedTransactionId)
                .ToList()
                .Where(candidate =>
                    candidate.Amount == transaction.Amount
                    || (!string.IsNullOrWhiteSpace(transaction.CheckNumber)
                        && !string.IsNullOrWhiteSpace(candidate.ReferenceId)
                        && string.Equals(candidate.ReferenceId.Trim(), transaction.CheckNumber.Trim(), StringComparison.OrdinalIgnoreCase)))
                .Take(2)
                .ToList();

            return strictMatches.Count == 1;
        }

        private static bool RuleMatches(BankFeedRule rule, BankFeedTransaction transaction)
        {
            if (rule.BankFeedAccountId.HasValue && rule.BankFeedAccountId.Value != transaction.BankFeedAccountId)
                return false;

            if (rule.Direction == "MoneyIn" && transaction.Amount <= 0)
                return false;

            if (rule.Direction == "MoneyOut" && transaction.Amount >= 0)
                return false;

            var description = NormalizeText(transaction.Description);
            var conditionResults = rule.Conditions.Select(condition => ConditionMatches(condition, description)).ToList();

            if (rule.MatchMode == "AnyTextWithDirection")
                return conditionResults.Any(c => c);

            return conditionResults.All(c => c);
        }

        private static bool ConditionMatches(BankFeedRuleCondition condition, string normalizedDescription)
        {
            var conditionValue = NormalizeText(condition.ConditionValue);

            return condition.ConditionType switch
            {
                "DescriptionContains" => normalizedDescription.Contains(conditionValue, StringComparison.OrdinalIgnoreCase),
                "DescriptionEquals" => string.Equals(normalizedDescription, conditionValue, StringComparison.OrdinalIgnoreCase),
                _ => false
            };
        }

        private string GetSetupStatus(BankFeedRule rule, BankFeedTransaction transaction)
        {
            var action = rule.Action;
            if (action == null)
                return "MissingSetup";

            if (DirectionActionError(rule.Direction, action.ActionType) != null)
                return "MissingSetup";

            if (action.AccountId.HasValue && !Uow.Accounts.Exists(c => c.AccountId == action.AccountId.Value && !c.Inactive))
                return "MissingSetup";

            if (action.TargetAccountId.HasValue && !Uow.Accounts.Exists(c => c.AccountId == action.TargetAccountId.Value && !c.Inactive))
                return "MissingSetup";

            if (action.PayeeId.HasValue && !Uow.Payees.Exists(c => c.PayeeId == action.PayeeId.Value && !c.IsClosed))
                return "MissingSetup";

            if (action.ActionType == "CreateMoneyOutExpense" && !action.PayeeId.HasValue)
                return "MissingSetup";

            if ((action.ActionType == "CreateMoneyOutExpense" || action.ActionType == "CreateMoneyInDeposit")
                && !action.AccountId.HasValue)
                return "MissingSetup";

            if (action.ActionType == "CreateTransfer" && !action.TargetAccountId.HasValue)
                return "MissingSetup";

            if (action.ActionType == "CreateTransfer" && action.TargetAccountId.HasValue)
            {
                var bankFeedAccount = Uow.BankFeedAccounts.GetByLongId(transaction.BankFeedAccountId);
                var sourceAccount = bankFeedAccount == null
                    ? null
                    : Uow.Accounts.Find(c => c.AccountId == bankFeedAccount.AccountId && !c.Inactive).SingleOrDefault();
                var targetAccount = Uow.Accounts.Find(c => c.AccountId == action.TargetAccountId.Value && !c.Inactive)
                    .SingleOrDefault();

                if (sourceAccount == null || targetAccount == null)
                    return "MissingSetup";

                if (!IsTransferSourceAccount(sourceAccount) || !IsTransferTargetAccount(targetAccount))
                    return "MissingSetup";

                if (sourceAccount.AccountId == targetAccount.AccountId)
                    return "MissingSetup";
            }

            if (action.ActionType == "CreateMoneyInDeposit")
            {
                var bankFeedAccount = Uow.BankFeedAccounts.GetByLongId(transaction.BankFeedAccountId);
                var sourceAccount = bankFeedAccount == null
                    ? null
                    : Uow.Accounts.Find(c => c.AccountId == bankFeedAccount.AccountId && !c.Inactive).SingleOrDefault();

                if (sourceAccount == null || !sourceAccount.IsAccountDebit)
                    return "MissingSetup";

                if (action.AccountId.HasValue)
                {
                    var actionAccount = Uow.Accounts.GetById(action.AccountId.Value);
                    if (actionAccount == null || actionAccount.Inactive || IsBlockedMoneyInAccount(actionAccount))
                        return "MissingSetup";

                    if (bankFeedAccount!.AccountId == action.AccountId.Value)
                        return "MissingSetup";
                }
            }

            return "Suggested";
        }

        private static bool IsBlockedMoneyInAccount(Account account)
        {
            return account.AccountCode == "@UF"
                || account.AccountCode == "@AR"
                || account.AccountCode == "@AP";
        }

        private static bool IsTransferSourceAccount(Account account)
        {
            return string.Equals(account.TypeName, "Bank", StringComparison.OrdinalIgnoreCase);
        }

        private static bool IsTransferTargetAccount(Account account)
        {
            return string.Equals(account.TypeName, "Bank", StringComparison.OrdinalIgnoreCase)
                || string.Equals(account.TypeName, "Cash", StringComparison.OrdinalIgnoreCase);
        }

        private static string BuildReason(BankFeedRule rule, string status)
        {
            return status switch
            {
                "Conflict" => $"Rule '{rule.RuleName}' matched, but another rule has the same priority.",
                "MissingSetup" => $"Rule '{rule.RuleName}' matched, but its action setup is missing or inactive.",
                _ => $"Rule '{rule.RuleName}' matched by {rule.MatchMode}."
            };
        }

        private static string NormalizeText(string? value)
        {
            if (string.IsNullOrWhiteSpace(value))
                return string.Empty;

            return Regex.Replace(value.Trim(), "\\s+", " ");
        }

        private static string Canonical(HashSet<string> allowedValues, string value)
        {
            return allowedValues.Single(c => string.Equals(c, value.Trim(), StringComparison.OrdinalIgnoreCase));
        }

        private static string? DirectionActionError(string? direction, string? actionType)
        {
            if (string.IsNullOrWhiteSpace(direction) || string.IsNullOrWhiteSpace(actionType))
                return "Rule direction and action type are required.";

            if (actionType.Equals("CreateMoneyOutExpense", StringComparison.OrdinalIgnoreCase)
                && !direction.Equals("MoneyOut", StringComparison.OrdinalIgnoreCase))
                return "Create Expense is only valid for Money Out rules.";

            if (actionType.Equals("CreateMoneyInDeposit", StringComparison.OrdinalIgnoreCase)
                && !direction.Equals("MoneyIn", StringComparison.OrdinalIgnoreCase))
                return "Create Deposit is only valid for Money In rules.";

            return null;
        }

        private void Validate(BankFeedRuleSaveReq req)
        {
            if (string.IsNullOrWhiteSpace(req.RuleName))
                throw new ArgumentException("Rule name is required.");

            if (!Directions.Contains(req.Direction))
                throw new ArgumentException("Rule direction is invalid.");

            if (!MatchModes.Contains(req.MatchMode))
                throw new ArgumentException("Rule match mode is invalid.");

            if (req.Priority <= 0)
                throw new ArgumentException("Rule order must be greater than 0.");

            var direction = Canonical(Directions, req.Direction);
            if (req.IsActive && Uow.BankFeedRules.Exists(c => c.IsActive
                && c.Direction == direction
                && c.Priority == req.Priority
                && c.BankFeedRuleId != req.BankFeedRuleId))
                throw new ArgumentException("Active rule order already exists for this direction.");

            if (req.BankFeedAccountId.HasValue && !Uow.BankFeedAccounts.Exists(c => c.BankFeedAccountId == req.BankFeedAccountId.Value))
                throw new ArgumentException("Bank feed account was not found.");

            if (req.Conditions == null || req.Conditions.Count == 0)
                throw new ArgumentException("At least one rule condition is required.");

            var conditionKeys = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var condition in req.Conditions)
            {
                if (!ConditionTypes.Contains(condition.ConditionType))
                    throw new ArgumentException("Rule condition type is invalid.");

                if (string.IsNullOrWhiteSpace(condition.ConditionValue))
                    throw new ArgumentException("Rule condition value is required.");

                var key = $"{condition.ConditionType.Trim()}|{condition.ConditionValue.Trim()}";
                if (!conditionKeys.Add(key))
                    throw new ArgumentException("Duplicate rule conditions are not allowed.");
            }

            if (req.Action == null)
                throw new ArgumentException("Rule action is required.");

            if (!ActionTypes.Contains(req.Action.ActionType))
                throw new ArgumentException("Rule action type is invalid.");

            var actionType = Canonical(ActionTypes, req.Action.ActionType);

            var directionActionError = DirectionActionError(direction, actionType);
            if (directionActionError != null)
                throw new ArgumentException(directionActionError);

            if ((actionType == "CreateMoneyOutExpense" || actionType == "CreateMoneyInDeposit")
                && !req.Action.AccountId.HasValue)
                throw new ArgumentException("Rule action account is required.");

            if (actionType == "CreateMoneyOutExpense" && !req.Action.PayeeId.HasValue)
                throw new ArgumentException("Rule action vendor is required.");

            if (actionType == "CreateTransfer" && !req.Action.TargetAccountId.HasValue)
                throw new ArgumentException("Rule transfer target account is required.");

            if (actionType == "Exclude"
                && (req.Action.PayeeId.HasValue || req.Action.AccountId.HasValue || req.Action.TargetAccountId.HasValue))
                throw new ArgumentException("Rule exclude action cannot have payee or account targets.");

            if (req.Action.PayeeId.HasValue && !Uow.Payees.Exists(c => c.PayeeId == req.Action.PayeeId.Value))
                throw new ArgumentException("Rule action payee was not found.");

            if (req.Action.AccountId.HasValue && !Uow.Accounts.Exists(c => c.AccountId == req.Action.AccountId.Value))
                throw new ArgumentException("Rule action account was not found.");

            if (req.Action.TargetAccountId.HasValue && !Uow.Accounts.Exists(c => c.AccountId == req.Action.TargetAccountId.Value))
                throw new ArgumentException("Rule transfer target account was not found.");

            if (actionType == "CreateMoneyOutExpense" && req.Action.AccountId.HasValue)
            {
                var actionAccount = Uow.Accounts.GetById(req.Action.AccountId.Value);
                if (actionAccount.AccountCode == "@AP")
                    throw new ArgumentException("Rule action account cannot be Accounts Payable.");

                if (req.BankFeedAccountId.HasValue)
                {
                    var sourceAccountId = Uow.BankFeedAccounts.GetByLongId(req.BankFeedAccountId.Value)?.AccountId;
                    if (sourceAccountId.HasValue && sourceAccountId == req.Action.AccountId)
                        throw new ArgumentException("Rule action account cannot be the bank feed account.");
                }
            }

            if (actionType == "CreateTransfer" && req.BankFeedAccountId.HasValue)
            {
                var bankFeedAccount = Uow.BankFeedAccounts.GetByLongId(req.BankFeedAccountId.Value);
                if (bankFeedAccount != null)
                {
                    var sourceAccount = Uow.Accounts.GetById(bankFeedAccount.AccountId);
                    if (sourceAccount != null && !IsTransferSourceAccount(sourceAccount))
                        throw new ArgumentException("Rule transfer only supports bank feed accounts mapped to a bank account.");

                    if (sourceAccount != null && sourceAccount.AccountId == req.Action.TargetAccountId)
                        throw new ArgumentException("Rule transfer target account cannot be the same as the bank feed account.");
                }
            }

            if (actionType == "CreateTransfer" && req.Action.TargetAccountId.HasValue)
            {
                var targetAccount = Uow.Accounts.GetById(req.Action.TargetAccountId.Value);
                if (targetAccount != null && !IsTransferTargetAccount(targetAccount))
                    throw new ArgumentException("Rule transfer target account must be Bank or Cash.");
            }

            if (actionType == "CreateMoneyInDeposit" && req.Action.AccountId.HasValue)
            {
                var actionAccount = Uow.Accounts.GetById(req.Action.AccountId.Value);
                if (IsBlockedMoneyInAccount(actionAccount))
                    throw new ArgumentException("Rule action account cannot be Undeposited Funds, Accounts Receivable, or Accounts Payable.");

                if (req.BankFeedAccountId.HasValue)
                {
                    var bankFeedAccount = Uow.BankFeedAccounts.GetByLongId(req.BankFeedAccountId.Value);
                    if (bankFeedAccount != null)
                    {
                        var sourceAccount = Uow.Accounts.GetById(bankFeedAccount.AccountId);
                        if (sourceAccount != null && !sourceAccount.IsAccountDebit)
                            throw new ArgumentException("Rule money-in only supports debit-side bank or cash accounts.");

                        if (bankFeedAccount.AccountId == req.Action.AccountId)
                            throw new ArgumentException("Rule action account cannot be the bank feed account.");
                    }
                }
            }
        }

        private List<BankFeedRuleDto> MapRules(IEnumerable<BankFeedRule> rules)
        {
            var ruleList = rules.ToList();
            var bankFeedAccountIds = ruleList
                .Where(c => c.BankFeedAccountId.HasValue)
                .Select(c => c.BankFeedAccountId!.Value)
                .Distinct()
                .ToList();
            var actionAccountIds = ruleList
                .SelectMany(c => new[] { c.Action?.AccountId, c.Action?.TargetAccountId })
                .Where(c => c.HasValue)
                .Select(c => c!.Value)
                .Distinct()
                .ToList();
            var payeeIds = ruleList
                .Where(c => c.Action?.PayeeId != null)
                .Select(c => c.Action!.PayeeId!.Value)
                .Distinct()
                .ToList();

            var bankFeedAccounts = Uow.BankFeedAccounts.GetAll()
                .Where(c => bankFeedAccountIds.Contains(c.BankFeedAccountId))
                .ToList();
            var bankFeedAccountMap = bankFeedAccounts.ToDictionary(c => c.BankFeedAccountId);
            var accountIds = actionAccountIds
                .Concat(bankFeedAccounts.Select(c => c.AccountId))
                .Distinct()
                .ToList();
            var accounts = Uow.Accounts.GetAll()
                .Where(c => accountIds.Contains(c.AccountId))
                .ToDictionary(c => c.AccountId);
            var payees = Uow.Payees.GetAll()
                .Where(c => payeeIds.Contains(c.PayeeId))
                .ToDictionary(c => c.PayeeId);

            return ruleList.Select(rule =>
            {
                BankFeedAccount? bankFeedAccount = null;
                if (rule.BankFeedAccountId.HasValue)
                {
                    bankFeedAccountMap.TryGetValue(rule.BankFeedAccountId.Value, out bankFeedAccount);
                }

                return new BankFeedRuleDto
                {
                    BankFeedRuleId = rule.BankFeedRuleId,
                    RuleName = rule.RuleName,
                    BankFeedAccountId = rule.BankFeedAccountId,
                    BankFeedAccountName = GetBankFeedAccountName(bankFeedAccount, accounts),
                    Direction = rule.Direction,
                    MatchMode = rule.MatchMode,
                    Priority = rule.Priority,
                    IsActive = rule.IsActive,
                    CreatedAt = rule.CreatedAt,
                    UpdatedAt = rule.UpdatedAt,
                    Conditions = rule.Conditions
                        .OrderBy(c => c.BankFeedRuleConditionId)
                        .Select(c => new BankFeedRuleConditionDto
                        {
                            BankFeedRuleConditionId = c.BankFeedRuleConditionId,
                            ConditionType = c.ConditionType,
                            ConditionValue = c.ConditionValue
                        })
                        .ToList(),
                    Action = MapAction(rule.Action, accounts, payees)
                };
            }).ToList();
        }

        private static string? GetBankFeedAccountName(BankFeedAccount? bankFeedAccount, Dictionary<int, Account> accounts)
        {
            if (bankFeedAccount == null)
                return null;

            accounts.TryGetValue(bankFeedAccount.AccountId, out var account);
            return string.IsNullOrWhiteSpace(bankFeedAccount.AccountNickname)
                ? account?.AccountName
                : bankFeedAccount.AccountNickname;
        }

        private static BankFeedRuleActionDto? MapAction(BankFeedRuleAction? action, Dictionary<int, Account> accounts, Dictionary<int, Payee> payees)
        {
            if (action == null)
                return null;

            Account? account = null;
            if (action.AccountId.HasValue)
            {
                accounts.TryGetValue(action.AccountId.Value, out account);
            }

            Account? targetAccount = null;
            if (action.TargetAccountId.HasValue)
            {
                accounts.TryGetValue(action.TargetAccountId.Value, out targetAccount);
            }

            Payee? payee = null;
            if (action.PayeeId.HasValue)
            {
                payees.TryGetValue(action.PayeeId.Value, out payee);
            }

            return new BankFeedRuleActionDto
            {
                BankFeedRuleActionId = action.BankFeedRuleActionId,
                ActionType = action.ActionType,
                PayeeId = action.PayeeId,
                PayeeName = payee?.PayeeName,
                AccountId = action.AccountId,
                AccountName = account?.AccountName,
                TargetAccountId = action.TargetAccountId,
                TargetAccountName = targetAccount?.AccountName,
                MemoTemplate = action.MemoTemplate,
                AppendBankDescription = action.AppendBankDescription
            };
        }

        private sealed class RuleEvaluation
        {
            public RuleEvaluation(BankFeedRule rule, string setupStatus)
            {
                Rule = rule;
                SetupStatus = setupStatus;
            }

            public BankFeedRule Rule { get; }

            public string SetupStatus { get; }
        }
    }
}
