SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- 2026-06-28: FIFO caller cutover -- repointed both FIFO calls to the unified
-- FIFO_Single_Allocation_Unified: @Stage='order' at StageId=0, @Stage='final' at StageId>=2.
-- Old EXECs kept commented (per workflow). Behavior identical; old SPs retained.
DROP PROCEDURE IF EXISTS [dbo].[Sales_CalcTotal]
GO
CREATE PROCEDURE [dbo].[Sales_CalcTotal] -- EXEC Sales_CalcTotal @SalesId=70693
    @SalesId INT
    --@SalesTotal DECIMAL(18,2) OUTPUT
AS
BEGIN
    -- Section 1: initialize working variables for post-posting follow-up.
    SET NOCOUNT ON;
    -- Legacy core-total variables kept here as commented reference only.
    -- DECLARE @SubTotal DECIMAL(18,2)
    -- DECLARE @TaxableTotal DECIMAL(18,2)
    -- DECLARE @TaxTotal DECIMAL(18,2)
    -- DECLARE @TaxPercent DECIMAL(18,4)
    DECLARE @SalesTotal DECIMAL(18,2)
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
    @TermId=TermId,
    @SalesTotal = SalesTotal
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
    SET @AmountDue = @SalesTotal - (@PaymentApplied + @DiscountApplied)
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
        -- 2026-06-28: cutover to unified allocator (order stage)
        -- EXEC [FIFO_Single_Allocation_OrderStage] @SalesId
        EXEC [FIFO_Single_Allocation_Unified] @SalesId, @Stage = 'order'
    IF @StageId>=2
        -- 2026-06-28: cutover to unified allocator (final stage)
        -- EXEC [FIFO_Single_Allocation] @SalesId
        EXEC [FIFO_Single_Allocation_Unified] @SalesId, @Stage = 'final'
    EXEC [Sales_CalcMargin] @SalesId
    -- End Summary:
    --   1. Core totals and base qty no longer belong to this helper.
    --   2. This proc owns AmountDue, due-date, discount, and aging follow-up.
    --   3. FIFO allocation remains here as post-posting follow-up.
    --   4. Margin recalculation remains here as post-posting follow-up.
END
GO
