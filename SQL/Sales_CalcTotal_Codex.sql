-- Sales_CalcTotal codex candidate
-- Date: 2026-04-15
-- Baseline: live dbo.Sales_CalcTotal from KLS_Latest
--
-- Summary:
--   Goal: keep Sales_CalcTotal focused on post-posting follow-up work after the
--   core sales/journal rows are already written.
--
-- Improvements:
--   1. Fail-fast guard for missing Sales row
--   2. Load TermId from Sales before calling Fn_Calc_DueDate
--   3. Core totals now belong to posting procedures, not this proc
--   4. Aging is derived from the sale's own due date, not Payee default term
--   5. Removed stray Customer.LastCallingStatus side effect
--   6. Base qty ownership now stays with posting procedures
--
-- What this proc still owns:
--   1. AmountDue / payment / discount follow-up
--   2. DueDate / discount date / aging refresh
--   3. Payee aging refresh
--   4. FIFO allocation follow-up
--   5. margin recalculation
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Sales_CalcTotal]

    @SalesId INT,
    @SalesTotal DECIMAL(18,2) OUTPUT
AS
BEGIN
    -- Section 1: initialize working variables for post-posting follow-up.
    SET NOCOUNT ON;

    -- Legacy core-total variables kept here as commented reference only.
    -- DECLARE @SubTotal DECIMAL(18,2)
    -- DECLARE @TaxableTotal DECIMAL(18,2)
    -- DECLARE @TaxTotal DECIMAL(18,2)
    -- DECLARE @TaxPercent DECIMAL(18,4)
    DECLARE @AmountDue DECIMAL(18,2)
    DECLARE @PaymentApplied DECIMAL(18,2);
    DECLARE @DiscountApplied DECIMAL(18,2);

    DECLARE @StageId INT
    DECLARE @ShipDate DATE
    DECLARE @PayeeId INT
    DECLARE @TermId INT;
    DECLARE @DueDate DATE;
    DECLARE @DiscDate DATE
    DECLARE @DiscRate DECIMAL(18,4)

    DECLARE @Aging INT=0;
    DECLARE @InvoiceAging INT=0;

    -- Section 2: load the persisted Sales header context used by due-date,
    -- aging, and FIFO follow-up logic.
    SELECT @StageId=StageId,
    @ShipDate=ShipDate,
    @PayeeId=ShipId,
    @TermId=TermId
    FROM Sales WHERE SalesId=@SalesId

    IF @PayeeId IS NULL
    BEGIN
        RAISERROR('Sales record not found for SalesId %d.', 16, 1, @SalesId)
        RETURN;
    END

    -- Section 3: legacy core-total ownership is kept here as commented
    -- reference only. Those totals now belong to Sales_Insert /
    -- Sales_PartialUpdate and should stay out of this proc.
    -- SELECT @SubTotal = ISNULL(SUM(ROUND(BillQty*UnitPrice,2)),0)
    -- FROM SalesDetail WHERE SalesId=@SalesId
    --
    -- SELECT @TaxableTotal = ISNULL(SUM(ROUND(BillQty*UnitPrice,2)),0)
    -- FROM SalesDetail WHERE SalesId=@SalesId AND IsTaxable=1
    --
    -- SET @TaxTotal = ROUND(@TaxableTotal * @TaxPercent,2)
    -- SET @SalesTotal = @SubTotal + @TaxTotal

    -- Section 4: calculate payment/discount follow-up and AmountDue from the
    -- already-persisted SalesTotal on the Sales header.
    SELECT
      @PaymentApplied = ISNULL(SUM(PaymentApplied), 0),
      @DiscountApplied = ISNULL(SUM(DiscountApplied), 0)
    FROM CustomerPaymentDetail
    WHERE SalesId = @SalesId;

    SELECT @AmountDue = SalesTotal - (@PaymentApplied + @DiscountApplied)
    FROM Sales
    WHERE SalesId = @SalesId

    -- Section 5: refresh due date, discount date, and aging from the sale's
    -- own stored term and ship date.
    --Calculate DueDate from ShipDate and Term
    EXEC Fn_Calc_DueDate @ShipDate,@TermId,@DueDate OUTPUT,@DiscDate OUTPUT,@DiscRate OUTPUT

    -- Calculate aging from the sale's own due date so term changes on Payee
    -- only affect future sales, not existing documents.
    SELECT @Aging = DATEDIFF(DAY,@DueDate,CAST(GETDATE() AS DATE))

    IF @Aging<0
        SET @Aging = 0

    IF @AmountDue=0
        SET @Aging=-1

    SELECT @InvoiceAging = DATEDIFF(DAY,@ShipDate,CAST(GETDATE() AS DATE))

    IF @InvoiceAging<0
        SET @InvoiceAging = 0

    IF @AmountDue=0
        SET @InvoiceAging=-1

    -- Section 6: write the post-posting financial follow-up back to Sales.
    UPDATE Sales SET
        AmountDue=@AmountDue,
        DueDate=@DueDate,
        Aging=@Aging,
        InvoiceAging=@InvoiceAging,
        DiscountDate=@DiscDate,
        DiscountPercent=@DiscRate,
        PaymentApplied=@PaymentApplied,
        DiscountApplied=@DiscountApplied
        --UpdatedAt=GETUTCDATE()
    WHERE SalesId=@SalesId

    -- Section 7: run downstream follow-up owned by this helper.
    EXEC [Payee_UpdateAging] @PayeeId,1

    IF @StageId=0
        EXEC [FIFO_Single_Allocation_OrderStage] @SalesId

    IF @StageId>=2
        EXEC [FIFO_Single_Allocation] @SalesId

    EXEC [Sales_CalcMargin] @SalesId
END
