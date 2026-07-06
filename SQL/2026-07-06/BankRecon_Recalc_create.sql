-- =============================================================================================
-- BankRecon_Recalc  (NEW)  — bank-recon-auto-difference-v1
-- Persist-only sibling of BankRecon_Balance: recompute a single reconciliation's balances via
-- Fn_BankRecon and write them back to BankRecon. Emits NO result set, so it is safe to call in a
-- loop / from another proc (BankRecon_RecalcByAccount) without polluting the caller's output.
-- The write-back block is byte-identical to BankRecon_Balance, so the modal and the list always agree.
-- =============================================================================================
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE [dbo].[BankRecon_Recalc]
    @BankReconId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SysTotalAmt       DECIMAL(18,2) = 0;
    DECLARE @BeginingBalance   DECIMAL(18,2) = 0;
    DECLARE @DepositAmt        DECIMAL(18,2) = 0;
    DECLARE @CheckAmt          DECIMAL(18,2) = 0;
    DECLARE @StatementBalance  DECIMAL(18,2) = 0;
    DECLARE @EndingBalance     DECIMAL(18,2) = 0;
    DECLARE @DifferenceAmount  DECIMAL(18,2) = 0;
    DECLARE @BeginingDate      DATE;
    DECLARE @StatementDate     DATE;
    DECLARE @IsReconciled      BIT = 0;

    EXEC [dbo].[Fn_BankRecon]
         @BankReconId        = @BankReconId,
         @SysTotalAmt        = @SysTotalAmt OUTPUT,
         @BeginingBalance    = @BeginingBalance OUTPUT,
         @DepositAmt         = @DepositAmt OUTPUT,
         @CheckAmt           = @CheckAmt OUTPUT,
         @StatementBalance   = @StatementBalance OUTPUT,
         @EndingBalance      = @EndingBalance OUTPUT,
         @DifferenceAmount   = @DifferenceAmount OUTPUT,
         @BeginingDate       = @BeginingDate OUTPUT,
         @StatementDate      = @StatementDate OUTPUT;

    SET @IsReconciled =
        CASE
            WHEN ISNULL(@DifferenceAmount, 0) = 0 THEN 1
            ELSE 0
        END;

    UPDATE [dbo].[BankRecon]
    SET
        SystemBalance     = @SysTotalAmt,
        BeginningBalance  = @BeginingBalance,
        EndingBalance     = @EndingBalance,
        DifferenceAmount  = @DifferenceAmount,
        IsReconciled      = @IsReconciled,
        UpdatedAt         = GETUTCDATE()
    WHERE BankReconId = @BankReconId;
END
GO
