-- ============================================================================
-- TaxCleanup.sql  --  Sales-tax schema cleanup (2026-05-16)
--
-- One-shot atomic bundle. Run on COGENT-2024\SQLEXPRESS / KLS_2026 (dev first).
-- After dev validation, archive to KLS\SQL\2026-05-16\TaxCleanup.sql.
-- Baselines:  KLS\SQL\2026-05-16\
-- Plan:       sales-tax-cleanup-plan.html
--
-- Steps:
--   1. Schema changes (add IsTaxExempt, rename two columns)
--   2. Data audit (Cash Ticket NonHR=1, reset 7 mis-flagged HRs, temple exempt)
--   3. Fn_IsItemTaxable rewrite (3-branch decision tree)
--
-- Atomicity: every step is idempotent. SET XACT_ABORT ON aborts on first error.
-- Step 2 (data audit) runs BEFORE step 3 (new function) so Cash Ticket and the
-- HR restaurants are correctly flagged before the new SP starts executing.
-- ============================================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

-- ============================================================================
-- Step 1. Schema changes
-- ============================================================================

-- 1a. Customer.IsTaxExempt  -- NEW column for full-exemption customers
IF COL_LENGTH('dbo.Customer', 'IsTaxExempt') IS NULL
BEGIN
    ALTER TABLE dbo.Customer
        ADD IsTaxExempt BIT NOT NULL
            CONSTRAINT DF_Customer_IsTaxExempt DEFAULT (0);
    PRINT '  + added Customer.IsTaxExempt';
END
ELSE
    PRINT '  = Customer.IsTaxExempt already exists, skipped';
GO

-- 1b. Customer.IsHRTaxable -> NonHR
IF COL_LENGTH('dbo.Customer', 'IsHRTaxable') IS NOT NULL
   AND COL_LENGTH('dbo.Customer', 'NonHR') IS NULL
BEGIN
    EXEC sp_rename 'dbo.Customer.IsHRTaxable', 'NonHR', 'COLUMN';
    PRINT '  + renamed Customer.IsHRTaxable -> Customer.NonHR';
END
ELSE
    PRINT '  = Customer.NonHR rename already applied, skipped';
GO

-- 1c. Item.IsHRExempt -> IsHRTaxable
IF COL_LENGTH('dbo.Item', 'IsHRExempt') IS NOT NULL
   AND COL_LENGTH('dbo.Item', 'IsHRTaxable') IS NULL
BEGIN
    EXEC sp_rename 'dbo.Item.IsHRExempt', 'IsHRTaxable', 'COLUMN';
    PRINT '  + renamed Item.IsHRExempt -> Item.IsHRTaxable';
END
ELSE
    PRINT '  = Item.IsHRTaxable rename already applied, skipped';
GO

-- ============================================================================
-- Step 2. Data audit (must run BEFORE new function takes effect)
-- ============================================================================

-- 2a. Cash Ticket: set NonHR = 1 so the new SP routes walk-ins through
--     branch 3a (Item.IsTaxable, ~275 retail items) instead of branch 3b
--     (Item.IsHRTaxable, ~52 consumption items). Preserves current behavior.
UPDATE c
SET    c.NonHR = 1
FROM   dbo.Customer c
JOIN   dbo.Payee    p ON p.PayeeId = c.PayeeId
WHERE  p.PayeeName = 'Cash Ticket'
  AND  c.NonHR <> 1;
PRINT CONCAT('  audit 2a Cash Ticket NonHR=1: rows = ', @@ROWCOUNT);

-- 2b. Reset the 7 mis-flagged HR restaurants (everyone except the temple).
--     Original IsHRTaxable=1 was wrong: these are real HR customers.
--     Setting NonHR=0 (default) routes them through HR branches:
--       - with valid RC -> Item.IsHRTaxable (consumption items)
--       - without RC    -> Item.IsHRTaxable (B2B consumption)
--     Matches their current Item.IsHRExempt routing pre-cleanup.
UPDATE dbo.Customer
SET    NonHR = 0
WHERE  PayeeId IN (
    301067,   -- China Pavilion          (HR restaurant)
    303375,   -- House of Pho (closed)   (HR restaurant)
    301752,   -- Great East (Customer)   (preserve current Item.IsHRTaxable routing)
    303894,   -- MORI LU                 (preserve current Item.IsHRTaxable routing)
    303933,   -- Susuru *code 2045*      (HR restaurant)
    303329,   -- Test123                 (test record)
    303937    -- Thai Elephant           (HR restaurant)
)
  AND  NonHR <> 0;
PRINT CONCAT('  audit 2b reset HR NonHR=0: rows = ', @@ROWCOUNT);

-- 2c. Guang Ming Temple: full exemption (church/temple/non-profit pattern).
--     IsTaxExempt short-circuits the decision tree at branch 1.
--     Existing NonHR=1 value is left as-is (irrelevant once IsTaxExempt fires).
UPDATE dbo.Customer
SET    IsTaxExempt = 1
WHERE  PayeeId = 302728   -- Guang Ming Temple (IBPS-Orlando)
  AND  IsTaxExempt <> 1;
PRINT CONCAT('  audit 2c temple IsTaxExempt=1: rows = ', @@ROWCOUNT);

GO

-- ============================================================================
-- Step 3. Fn_IsItemTaxable rewrite
-- ============================================================================
-- Rollback artifact for the function: KLS\SQL\2026-05-16\Fn_IsItemTaxable_live_baseline.sql
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
        2026-05-16 sales-tax-cleanup rewrite.
        Baseline body: KLS\SQL\2026-05-16\Fn_IsItemTaxable_live_baseline.sql
        Plan:          sales-tax-cleanup-plan.html

        Decision tree:
          1. Customer.IsTaxExempt = 1            -> NO tax  (full exemption)
          2. Valid resale cert for ShipDate:
                Customer.NonHR = 1               -> NO tax  (pure non-HR resale)
                else  (HR, default)              -> Item.IsHRTaxable
          3. No valid RC:
                Customer.NonHR = 1               -> Item.IsTaxable     (full retail)
                else  (HR, default)              -> Item.IsHRTaxable   (B2B consumption)
    */
    DECLARE @IsTaxable       BIT = 0;
    DECLARE @IsTaxExempt     BIT = 0;
    DECLARE @NonHR           BIT = 0;
    DECLARE @RCNumber        NVARCHAR(50);
    DECLARE @RCExpireDate    DATE;
    DECLARE @ItemIsTaxable   BIT = 0;
    DECLARE @ItemIsHRTaxable BIT = 0;

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
        IF @NonHR = 1
            SET @IsTaxable = 0;
        ELSE
            SET @IsTaxable = @ItemIsHRTaxable;
    END
    ELSE
    BEGIN
        IF @NonHR = 1
            SET @IsTaxable = @ItemIsTaxable;
        ELSE
            SET @IsTaxable = @ItemIsHRTaxable;
    END;

    INSERT INTO @Results(ItemId, IsTaxable) VALUES (@ItemId, @IsTaxable);
    RETURN;
END
GO

PRINT '';
PRINT '== TaxCleanup deploy complete ==';
GO
