-- ============================================================================
-- HRTaxSchedule.sql  --  HR tax logic as opt-in extension (2026-05-16)
--
-- Round 2 follow-up to TaxCleanup.sql. Run on COGENT-2024\SQLEXPRESS / KLS_2026
-- (dev first). After dev validation, archive to:
--     KLS\SQL\2026-05-16\HRTaxSchedule\HRTaxSchedule.sql
--
-- Baselines:
--     KLS\SQL\2026-05-16\HRTaxSchedule\Fn_IsItemTaxable_live_baseline.sql
--         (post-cleanup 3-branch body, captured before this round)
--
-- Plan: hrtaxschedule-plan.html
--
-- Steps:
--   1. Seed SystemSetting row HR_TAX_SCHEDULE = '1' (KLS Foods opt-in)
--   2. Rewrite Fn_IsItemTaxable to read the flag and branch:
--        OFF (product default) -> simple tree: exempt / valid RC / Item.IsTaxable
--        ON  (KLS Foods)       -> 3-branch HR tree (NonHR / Item.IsHRTaxable)
--
-- Product default is OFF: missing row OR value '0' both yield simple-mode behavior.
-- Other tenants don't need this script; they just inherit simple-mode for free.
--
-- Atomicity: both steps are idempotent. SET XACT_ABORT ON aborts on first error.
-- ============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

-- ============================================================================
-- Step 1. SystemSetting seed (KLS Foods opt-in to HR mode)
-- ============================================================================
-- Idempotent: existing row left alone so re-running won't clobber a manual flip.
-- For non-KLS-Foods deployments: delete this whole block (or change '1' to '0').
-- The SP's ISNULL(..., 0) fallback gives identical simple-mode behavior either way.

IF NOT EXISTS (SELECT 1 FROM dbo.SystemSetting WHERE SettingKey = 'HR_TAX_SCHEDULE')
BEGIN
    INSERT INTO dbo.SystemSetting (SettingKey, SettingValue, DataType, Description, CreatedAt)
    VALUES (
        'HR_TAX_SCHEDULE',
        '1',
        'bit',
        'KLS Foods opt-in. When 1, Fn_IsItemTaxable runs the 3-branch HR tree (NonHR / Item.IsHRTaxable). When 0 or missing, simple tree: exempt / valid RC / Item.IsTaxable.',
        GETUTCDATE()
    );
    PRINT '  + seeded SystemSetting HR_TAX_SCHEDULE = ''1'' (KLS Foods opt-in)';
END
ELSE
    PRINT '  = SystemSetting HR_TAX_SCHEDULE already exists, skipped';
GO

-- ============================================================================
-- Step 2. Fn_IsItemTaxable rewrite (flag wrapper around 3-branch body)
-- ============================================================================
-- Rollback artifact: KLS\SQL\2026-05-16\HRTaxSchedule\Fn_IsItemTaxable_live_baseline.sql
-- (CLAUDE.md's _prev rename rule applies to stored procedures, not functions.)

CREATE OR ALTER FUNCTION dbo.Fn_IsItemTaxable
(
    @ItemId   INT,
    @ShipDate DATE,
    @PayeeId  INT
)
RETURNS @Results TABLE
(
    ItemId    INT NOT NULL,
    IsTaxable BIT NOT NULL
)
AS
BEGIN
    /*
        2026-05-16 HRTaxSchedule round.
        Baseline (pre-flag, 3-branch body):
            KLS\SQL\2026-05-16\HRTaxSchedule\Fn_IsItemTaxable_live_baseline.sql
        Plan: hrtaxschedule-plan.html

        Product default = OFF (simple tree). KLS Foods seeds HR_TAX_SCHEDULE = '1'.

        Decision tree:
          @HRTaxSchedule = 0  (DEFAULT, simple)
            1. Customer.IsTaxExempt           -> 0
            2. Valid RC                       -> 0
            3. No RC                          -> Item.IsTaxable

          @HRTaxSchedule = 1  (KLS Foods opt-in)
            1. Customer.IsTaxExempt           -> 0
            2. Valid RC:
                 Customer.NonHR = 1           -> 0
                 else (HR, default)           -> Item.IsHRTaxable
            3. No RC:
                 Customer.NonHR = 1           -> Item.IsTaxable
                 else (HR, default)           -> Item.IsHRTaxable
    */
    DECLARE @IsTaxable       BIT = 0;
    DECLARE @HRTaxSchedule   BIT;
    DECLARE @IsTaxExempt     BIT = 0;
    DECLARE @NonHR           BIT = 0;
    DECLARE @RCNumber        NVARCHAR(50);
    DECLARE @RCExpireDate    DATE;
    DECLARE @ItemIsTaxable   BIT = 0;
    DECLARE @ItemIsHRTaxable BIT = 0;

    -- Read tenant flag. Missing / NULL / non-truthy value all collapse to 0 (simple mode).
    SELECT @HRTaxSchedule = CASE
        WHEN LOWER(ISNULL(SettingValue, '0')) IN ('1', 'true') THEN 1
        ELSE 0
    END
    FROM dbo.SystemSetting
    WHERE SettingKey = 'HR_TAX_SCHEDULE';
    SET @HRTaxSchedule = ISNULL(@HRTaxSchedule, 0);

    SELECT  @IsTaxExempt  = ISNULL(IsTaxExempt, 0),
            @NonHR        = ISNULL(NonHR, 0),
            @RCNumber     = RCNumber,
            @RCExpireDate = RCExpireDate
    FROM    dbo.Customer
    WHERE   PayeeId = @PayeeId;

    SELECT  @ItemIsTaxable   = ISNULL(IsTaxable, 0),
            @ItemIsHRTaxable = ISNULL(IsHRTaxable, 0)
    FROM    dbo.Item
    WHERE   ItemId = @ItemId;

    IF @IsTaxExempt = 1
        SET @IsTaxable = 0;
    ELSE IF @RCNumber IS NOT NULL AND @ShipDate <= @RCExpireDate
    BEGIN
        IF @HRTaxSchedule = 0
            SET @IsTaxable = 0;                       -- simple: valid RC = no tax
        ELSE IF @NonHR = 1
            SET @IsTaxable = 0;                       -- HR mode: pure non-HR resale
        ELSE
            SET @IsTaxable = @ItemIsHRTaxable;        -- HR mode: HR + consumption taxed
    END
    ELSE
    BEGIN
        IF @HRTaxSchedule = 0
            SET @IsTaxable = @ItemIsTaxable;          -- simple: no RC = standard taxability
        ELSE IF @NonHR = 1
            SET @IsTaxable = @ItemIsTaxable;          -- HR mode: non-HR full retail
        ELSE
            SET @IsTaxable = @ItemIsHRTaxable;        -- HR mode: HR B2B consumption only
    END;

    INSERT INTO @Results(ItemId, IsTaxable) VALUES (@ItemId, @IsTaxable);
    RETURN;
END
GO

PRINT '';
PRINT '== HRTaxSchedule deploy complete ==';
GO
