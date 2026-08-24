SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- Rollback for BankFeedRule_Schema.sql.
-- Removes Bank Feed rule suggestion/rule tables and rule permissions.
-- Idempotent / guarded. Deletes only the three rule permission keys.

SET XACT_ABORT ON;
BEGIN TRAN;

DELETE rp
FROM dbo.RolePermission rp
JOIN dbo.Permission p ON p.PermissionId = rp.PermissionId
WHERE p.PermissionKey IN (
    N'Accounting.BankFeed.Rule.List',
    N'Accounting.BankFeed.Rule.Manage',
    N'Accounting.BankFeed.Rule.Recalculate'
);

DELETE FROM dbo.Permission
WHERE PermissionKey IN (
    N'Accounting.BankFeed.Rule.List',
    N'Accounting.BankFeed.Rule.Manage',
    N'Accounting.BankFeed.Rule.Recalculate'
);

COMMIT;
GO

IF OBJECT_ID('dbo.BankFeedRuleSuggestion', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_BankFeedRuleSuggestion_PreferredActive' AND object_id = OBJECT_ID('dbo.BankFeedRuleSuggestion'))
        DROP INDEX UX_BankFeedRuleSuggestion_PreferredActive ON dbo.BankFeedRuleSuggestion;

    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_BankFeedRuleSuggestion_RuleStatus' AND object_id = OBJECT_ID('dbo.BankFeedRuleSuggestion'))
        DROP INDEX IX_BankFeedRuleSuggestion_RuleStatus ON dbo.BankFeedRuleSuggestion;

    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_BankFeedRuleSuggestion_TxStatus' AND object_id = OBJECT_ID('dbo.BankFeedRuleSuggestion'))
        DROP INDEX IX_BankFeedRuleSuggestion_TxStatus ON dbo.BankFeedRuleSuggestion;

    DROP TABLE dbo.BankFeedRuleSuggestion;
END
GO

IF OBJECT_ID('dbo.BankFeedRuleAction', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_BankFeedRuleAction_Rule' AND object_id = OBJECT_ID('dbo.BankFeedRuleAction'))
        DROP INDEX UX_BankFeedRuleAction_Rule ON dbo.BankFeedRuleAction;

    DROP TABLE dbo.BankFeedRuleAction;
END
GO

IF OBJECT_ID('dbo.BankFeedRuleCondition', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_BankFeedRuleCondition_RuleTypeValue' AND object_id = OBJECT_ID('dbo.BankFeedRuleCondition'))
        DROP INDEX UX_BankFeedRuleCondition_RuleTypeValue ON dbo.BankFeedRuleCondition;

    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_BankFeedRuleCondition_RuleType' AND object_id = OBJECT_ID('dbo.BankFeedRuleCondition'))
        DROP INDEX IX_BankFeedRuleCondition_RuleType ON dbo.BankFeedRuleCondition;

    DROP TABLE dbo.BankFeedRuleCondition;
END
GO

IF OBJECT_ID('dbo.BankFeedRule', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_BankFeedRule_ActiveScopeDirectionPriority' AND object_id = OBJECT_ID('dbo.BankFeedRule'))
        DROP INDEX IX_BankFeedRule_ActiveScopeDirectionPriority ON dbo.BankFeedRule;

    DROP TABLE dbo.BankFeedRule;
END
GO
