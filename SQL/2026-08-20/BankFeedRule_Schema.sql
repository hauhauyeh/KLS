SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================================================================
-- Bank Feed Rule Engine foundation schema.
-- Plan: plan-01-bank-feed-rule-engine-foundation.md (Slice 1)
--
-- Adds rule header, condition, action and persisted suggestion tables.
-- Also seeds rule-maintenance permissions under existing Accounting.BankFeed.
-- Suggestion-only foundation: no accounting posting, no UI, no Bank Feed list change.
--
-- Idempotent / guarded. Safe to re-run. Rollback: BankFeedRule_Schema_rollback.sql
-- =============================================================================================

IF OBJECT_ID('dbo.BankFeedRule', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.BankFeedRule
    (
        BankFeedRuleId    INT IDENTITY(1,1) NOT NULL,
        RuleName          NVARCHAR(200) NOT NULL,
        BankFeedAccountId BIGINT NULL,
        Direction         VARCHAR(20) NOT NULL,
        MatchMode         VARCHAR(30) NOT NULL,
        Priority          INT NOT NULL CONSTRAINT DF_BankFeedRule_Priority DEFAULT (100),
        IsActive          BIT NOT NULL CONSTRAINT DF_BankFeedRule_IsActive DEFAULT (1),
        CreatedAt         DATETIME NOT NULL CONSTRAINT DF_BankFeedRule_CreatedAt DEFAULT (GETUTCDATE()),
        UpdatedAt         DATETIME NULL,

        CONSTRAINT PK_BankFeedRule
            PRIMARY KEY CLUSTERED (BankFeedRuleId),

        CONSTRAINT FK_BankFeedRule_BankFeedAccount
            FOREIGN KEY (BankFeedAccountId)
            REFERENCES dbo.BankFeedAccount(BankFeedAccountId),

        CONSTRAINT CK_BankFeedRule_Direction
            CHECK (Direction IN ('MoneyIn', 'MoneyOut')),

        CONSTRAINT CK_BankFeedRule_MatchMode
            CHECK (MatchMode IN ('All', 'AnyTextWithDirection')),

        CONSTRAINT CK_BankFeedRule_RuleName_NotBlank
            CHECK (LEN(LTRIM(RTRIM(RuleName))) > 0)
    );
END
GO

IF OBJECT_ID('dbo.BankFeedRuleCondition', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.BankFeedRuleCondition
    (
        BankFeedRuleConditionId INT IDENTITY(1,1) NOT NULL,
        BankFeedRuleId          INT NOT NULL,
        ConditionType           VARCHAR(50) NOT NULL,
        ConditionValue          NVARCHAR(500) NOT NULL,
        CreatedAt               DATETIME NOT NULL CONSTRAINT DF_BankFeedRuleCondition_CreatedAt DEFAULT (GETUTCDATE()),

        CONSTRAINT PK_BankFeedRuleCondition
            PRIMARY KEY CLUSTERED (BankFeedRuleConditionId),

        CONSTRAINT FK_BankFeedRuleCondition_BankFeedRule
            FOREIGN KEY (BankFeedRuleId)
            REFERENCES dbo.BankFeedRule(BankFeedRuleId),

        CONSTRAINT CK_BankFeedRuleCondition_ConditionType
            CHECK (ConditionType IN ('DescriptionContains', 'DescriptionEquals')),

        CONSTRAINT CK_BankFeedRuleCondition_ConditionValue_NotBlank
            CHECK (LEN(LTRIM(RTRIM(ConditionValue))) > 0)
    );
END
GO

IF OBJECT_ID('dbo.BankFeedRuleAction', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.BankFeedRuleAction
    (
        BankFeedRuleActionId INT IDENTITY(1,1) NOT NULL,
        BankFeedRuleId       INT NOT NULL,
        ActionType           VARCHAR(50) NOT NULL,
        PayeeId              INT NULL,
        AccountId            INT NULL,
        TargetAccountId      INT NULL,
        MemoTemplate         NVARCHAR(500) NULL,
        AppendBankDescription BIT NOT NULL CONSTRAINT DF_BankFeedRuleAction_AppendBankDescription DEFAULT (1),
        CreatedAt            DATETIME NOT NULL CONSTRAINT DF_BankFeedRuleAction_CreatedAt DEFAULT (GETUTCDATE()),
        UpdatedAt            DATETIME NULL,

        CONSTRAINT PK_BankFeedRuleAction
            PRIMARY KEY CLUSTERED (BankFeedRuleActionId),

        CONSTRAINT FK_BankFeedRuleAction_BankFeedRule
            FOREIGN KEY (BankFeedRuleId)
            REFERENCES dbo.BankFeedRule(BankFeedRuleId),

        CONSTRAINT FK_BankFeedRuleAction_Payee
            FOREIGN KEY (PayeeId)
            REFERENCES dbo.Payee(PayeeId),

        CONSTRAINT FK_BankFeedRuleAction_Account
            FOREIGN KEY (AccountId)
            REFERENCES dbo.Account(AccountId),

        CONSTRAINT FK_BankFeedRuleAction_TargetAccount
            FOREIGN KEY (TargetAccountId)
            REFERENCES dbo.Account(AccountId),

        CONSTRAINT CK_BankFeedRuleAction_ActionType
            CHECK (ActionType IN ('CreateMoneyOutExpense', 'CreateMoneyInDeposit', 'CreateTransfer', 'Exclude')),

        CONSTRAINT CK_BankFeedRuleAction_RequiredTargets
            CHECK (
                (ActionType = 'CreateMoneyOutExpense' AND AccountId IS NOT NULL)
                OR (ActionType = 'CreateMoneyInDeposit' AND AccountId IS NOT NULL)
                OR (ActionType = 'CreateTransfer' AND TargetAccountId IS NOT NULL)
                OR (ActionType = 'Exclude')
            )
    );
END
GO

IF OBJECT_ID('dbo.BankFeedRuleSuggestion', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.BankFeedRuleSuggestion
    (
        BankFeedRuleSuggestionId BIGINT IDENTITY(1,1) NOT NULL,
        BankFeedTransactionId    BIGINT NOT NULL,
        BankFeedRuleId           INT NOT NULL,
        SuggestionStatus         VARCHAR(30) NOT NULL,
        IsPreferred              BIT NOT NULL CONSTRAINT DF_BankFeedRuleSuggestion_IsPreferred DEFAULT (0),
        Score                    INT NOT NULL CONSTRAINT DF_BankFeedRuleSuggestion_Score DEFAULT (0),
        Reason                   NVARCHAR(1000) NULL,
        CreatedAt                DATETIME NOT NULL CONSTRAINT DF_BankFeedRuleSuggestion_CreatedAt DEFAULT (GETUTCDATE()),
        AppliedAt                DATETIME NULL,
        AppliedBy                INT NULL,
        DismissedAt              DATETIME NULL,
        DismissedBy              INT NULL,

        CONSTRAINT PK_BankFeedRuleSuggestion
            PRIMARY KEY CLUSTERED (BankFeedRuleSuggestionId),

        CONSTRAINT FK_BankFeedRuleSuggestion_BankFeedTransaction
            FOREIGN KEY (BankFeedTransactionId)
            REFERENCES dbo.BankFeedTransaction(BankFeedTransactionId),

        CONSTRAINT FK_BankFeedRuleSuggestion_BankFeedRule
            FOREIGN KEY (BankFeedRuleId)
            REFERENCES dbo.BankFeedRule(BankFeedRuleId),

        CONSTRAINT CK_BankFeedRuleSuggestion_Status
            CHECK (SuggestionStatus IN ('Suggested', 'Conflict', 'MissingSetup', 'Applied', 'Dismissed', 'Expired'))
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = 'IX_BankFeedRule_ActiveScopeDirectionPriority'
                 AND object_id = OBJECT_ID('dbo.BankFeedRule'))
    CREATE NONCLUSTERED INDEX IX_BankFeedRule_ActiveScopeDirectionPriority
        ON dbo.BankFeedRule(IsActive, BankFeedAccountId, Direction, Priority);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = 'IX_BankFeedRuleCondition_RuleType'
                 AND object_id = OBJECT_ID('dbo.BankFeedRuleCondition'))
    CREATE NONCLUSTERED INDEX IX_BankFeedRuleCondition_RuleType
        ON dbo.BankFeedRuleCondition(BankFeedRuleId, ConditionType);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = 'UX_BankFeedRuleCondition_RuleTypeValue'
                 AND object_id = OBJECT_ID('dbo.BankFeedRuleCondition'))
    CREATE UNIQUE NONCLUSTERED INDEX UX_BankFeedRuleCondition_RuleTypeValue
        ON dbo.BankFeedRuleCondition(BankFeedRuleId, ConditionType, ConditionValue);
GO

-- V1 allows exactly one action per rule.
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = 'UX_BankFeedRuleAction_Rule'
                 AND object_id = OBJECT_ID('dbo.BankFeedRuleAction'))
    CREATE UNIQUE NONCLUSTERED INDEX UX_BankFeedRuleAction_Rule
        ON dbo.BankFeedRuleAction(BankFeedRuleId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = 'IX_BankFeedRuleSuggestion_TxStatus'
                 AND object_id = OBJECT_ID('dbo.BankFeedRuleSuggestion'))
    CREATE NONCLUSTERED INDEX IX_BankFeedRuleSuggestion_TxStatus
        ON dbo.BankFeedRuleSuggestion(BankFeedTransactionId, SuggestionStatus);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = 'IX_BankFeedRuleSuggestion_RuleStatus'
                 AND object_id = OBJECT_ID('dbo.BankFeedRuleSuggestion'))
    CREATE NONCLUSTERED INDEX IX_BankFeedRuleSuggestion_RuleStatus
        ON dbo.BankFeedRuleSuggestion(BankFeedRuleId, SuggestionStatus);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = 'UX_BankFeedRuleSuggestion_PreferredActive'
                 AND object_id = OBJECT_ID('dbo.BankFeedRuleSuggestion'))
    CREATE UNIQUE NONCLUSTERED INDEX UX_BankFeedRuleSuggestion_PreferredActive
        ON dbo.BankFeedRuleSuggestion(BankFeedTransactionId)
        WHERE IsPreferred = 1
          AND SuggestionStatus IN ('Suggested', 'MissingSetup');
GO

-- Bank Feed rule permissions. Parent: Accounting.BankFeed (1400).
SET XACT_ABORT ON;
BEGIN TRAN;

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionKey = N'Accounting.BankFeed')
BEGIN
    THROW 51000, 'Missing parent permission Accounting.BankFeed.', 1;
END;

DECLARE @RulePerms TABLE
(
    PermissionId INT NOT NULL PRIMARY KEY,
    PermissionKey NVARCHAR(150) NOT NULL,
    DisplayName NVARCHAR(255) NOT NULL,
    [Action] NVARCHAR(100) NOT NULL,
    PermissionType NVARCHAR(50) NOT NULL,
    SortOrder INT NOT NULL
);

INSERT INTO @RulePerms (PermissionId, PermissionKey, DisplayName, [Action], PermissionType, SortOrder)
VALUES
    (1407, N'Accounting.BankFeed.Rule.List', N'View Bank Feed Rules', N'Rule.List', N'page', 1407),
    (1408, N'Accounting.BankFeed.Rule.Manage', N'Manage Bank Feed Rules', N'Rule.Manage', N'button', 1408),
    (1409, N'Accounting.BankFeed.Rule.Recalculate', N'Recalculate Bank Feed Rule Suggestions', N'Rule.Recalculate', N'button', 1409);

IF EXISTS (
    SELECT 1
    FROM dbo.Permission p
    JOIN @RulePerms rp ON rp.PermissionId = p.PermissionId
    WHERE p.PermissionKey <> rp.PermissionKey
)
BEGIN
    THROW 51000, 'One or more Bank Feed rule permission IDs are already used by another permission.', 1;
END;

UPDATE p
SET DisplayName = rp.DisplayName,
    [Module] = N'Accounting',
    [Resource] = N'BankFeed',
    [Action] = rp.[Action],
    PermissionType = rp.PermissionType,
    ParentPermissionId = 1400,
    SortOrder = rp.SortOrder,
    IsActive = 1
FROM dbo.Permission p
JOIN @RulePerms rp ON rp.PermissionKey = p.PermissionKey;

SET IDENTITY_INSERT dbo.Permission ON;

INSERT INTO dbo.Permission
    (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action],
     PermissionType, ParentPermissionId, SortOrder, Description, OldKey, IsActive, CreatedAt)
SELECT rp.PermissionId, rp.PermissionKey, rp.DisplayName, N'Accounting', N'BankFeed', rp.[Action],
       rp.PermissionType, 1400, rp.SortOrder, NULL, NULL, 1, SYSDATETIME()
FROM @RulePerms rp
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.Permission p
    WHERE p.PermissionKey = rp.PermissionKey
);

SET IDENTITY_INSERT dbo.Permission OFF;

COMMIT;

SELECT PermissionId, PermissionKey, DisplayName, PermissionType, ParentPermissionId, SortOrder, IsActive
FROM dbo.Permission
WHERE PermissionKey IN (
    N'Accounting.BankFeed.Rule.List',
    N'Accounting.BankFeed.Rule.Manage',
    N'Accounting.BankFeed.Rule.Recalculate'
)
ORDER BY PermissionId;
GO
