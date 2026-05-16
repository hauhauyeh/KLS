
-- ============================================================================
-- Step 3. Fn_IsItemTaxable rewrite
-- ============================================================================
-- Rollback artifact for the function: KLS\SQL\2026-05-16\Fn_IsItemTaxable_live_baseline.sql
-- (CLAUDE.md's _prev rename rule applies to stored procedures, not functions.)

CREATE   FUNCTION dbo.Fn_IsItemTaxable
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

