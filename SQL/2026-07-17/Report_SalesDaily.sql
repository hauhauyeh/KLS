SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- FIX_ICREDIT_AMOUNT_SIGN 2026-07-17 (reader): SalesTotal now sums td.CrDeAmount over the
-- income-class (non-@COGS) rows instead of td.Amount. For income-account detail rows CrDeAmount =
-- the signed business value under BOTH the old (buggy) and new posting conventions (credit-normal
-- income: +value; debit-normal contra-income @ICREDIT/@IDG: -magnitude), so this report returns
-- IDENTICAL results before and after the Amount-sign data fix (TxDetail_FixAmountSign_292_310.sql).
-- Without this change, the data fix would flip @ICREDIT/@IDG Amount to +magnitude and credit/
-- discount lines would ADD to SalesTotal instead of netting it down. Cost (@COGS) stays on
-- td.Amount -- COGS posting convention is unchanged.
--
-- FIX_SALESDAILY_IDG_VAR 2026-07-17 (approved 2026-07-17, behavior-changing): the third account
-- lookup assigned the @IDG AccountId into @ISALEAccountId (copy-paste), leaving @IDGAccountId
-- NULL. Effects of the bug: (a) the DiscountData CTE never matched (td.AccountId = NULL), so
-- payment-discount rows were silently ABSENT from the report since it shipped; (b) JournalData
-- relabeled @COGS rows with the @IDG AccountId/AccountName. Both fixed here. Activating
-- DiscountData also required fixing its latent join mismatch: it emitted pd.SalesId as
-- SourceDocNumber, but the final SELECT joins Sales ON s.SalesNumber = f.SourceDocNumber --
-- SalesId and SalesNumber are different sequences, so discount rows would have attached to the
-- WRONG invoices. DiscountData now resolves the real SalesNumber via a Sales join on pd.SalesId.
-- EXPECTED OUTPUT CHANGE after deploy: payment-discount rows (SALES DISCOUNT GIVEN, negative
-- SalesTotal, dated by payment TxDate) start appearing, and COGS rows carry the @ISALE label as
-- originally intended. SalesTotal/Cost/margin math for existing rows is unchanged (those sums key
-- off @COGSAccountId only).
-- See baseline: KLS/SQL/2026-07-17/Report_SalesDaily_live_baseline.sql
CREATE OR ALTER PROCEDURE [dbo].[Report_SalesDaily] --[Report_SalesDaily] '02/01/2026','02/28/2026',null
    @StartDate DATE,
    @EndDate DATE,
    @SalesRepId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TotalSales DECIMAL(18,2);
    DECLARE @COGSAccountId INT
	DECLARE @ISALEAccountId INT
	DECLARE @IDGAccountId INT

    SELECT @COGSAccountId = AccountId FROM Account WHERE AccountCode = '@COGS'
	SELECT @ISALEAccountId = AccountId FROM Account WHERE AccountCode = '@ISALE'
	-- 2026-07-17 FIX_SALESDAILY_IDG_VAR: assign into @IDGAccountId (was overwriting @ISALEAccountId,
	-- leaving @IDGAccountId NULL -> DiscountData dead, COGS rows mislabeled). See header.
	-- OLD: SELECT @ISALEAccountId = AccountId FROM Account WHERE AccountCode = '@IDG'
	SELECT @IDGAccountId = AccountId FROM Account WHERE AccountCode = '@IDG'

    ;WITH IncomeAccounts AS
    (
        SELECT AccountId 
        FROM Account a INNER JOIN AccountCategory c ON a.AccountCategoryId = c.AccountCategoryId
        WHERE c.ClassCode = 'I' 
        UNION ALL 
        SELECT @COGSAccountId
    ),

    JournalData AS
    (
        SELECT 
            t.TxDate,
            t.SourceDocNumber,
            CASE WHEN td.AccountId = @COGSAccountId THEN @ISALEAccountId
                 ELSE td.AccountId END AS AccountId,

            -- 2026-07-17 FIX_ICREDIT_AMOUNT_SIGN: sign-independent sales total (see header).
            -- OLD: SUM(CASE WHEN td.AccountId != @COGSAccountId
            --          THEN td.Amount ELSE 0 END) AS SalesTotal,
            SUM(CASE WHEN td.AccountId != @COGSAccountId
                     THEN td.CrDeAmount ELSE 0 END) AS SalesTotal,

            SUM(CASE WHEN td.AccountId = @COGSAccountId 
                     THEN td.Amount ELSE 0 END) AS Cost
        FROM TransactionJournal t
        INNER JOIN TransactionJournalDetail td 
            ON t.TxId = td.TxId
        INNER JOIN IncomeAccounts ia 
            ON ia.AccountId = td.AccountId
        WHERE t.SourceDocType = 'Sales'
          AND t.TxDate BETWEEN @StartDate AND @EndDate
        GROUP BY t.TxDate, t.SourceDocNumber, td.AccountId
    ),

    DiscountData AS
    (
        SELECT
            t.TxDate,
            -- 2026-07-17 FIX_SALESDAILY_IDG_VAR: emit the invoice's SalesNumber, not its SalesId.
            -- The final SELECT joins Sales ON s.SalesNumber = f.SourceDocNumber; pd.SalesId is a
            -- SalesId (different sequence), so it would attach discounts to the wrong invoices.
            -- OLD: pd.SalesId AS SourceDocNumber,
            ds.SalesNumber AS SourceDocNumber,
            td.AccountId AS AccountId,
            pd.DiscountApplied * -1 AS SalesTotal,
            0 AS Cost
        FROM TransactionJournal t
        INNER JOIN TransactionJournalDetail td ON t.TxId = td.TxId
        INNER JOIN CustomerPayment c ON c.PaymentNumber = t.SourceDocNumber
        INNER JOIN CustomerPaymentDetail pd
            ON pd.CustomerPaymentId = c.CustomerPaymentId
        -- 2026-07-17 FIX_SALESDAILY_IDG_VAR: resolve SalesId -> SalesNumber (also naturally drops
        -- non-document rows where pd.SalesId = 0, e.g. AsIncome/AsRefund extra-disposition rows).
        INNER JOIN Sales ds ON ds.SalesId = pd.SalesId
        WHERE t.SourceDocType = 'Customer Payment'
          AND td.AccountId = @IDGAccountId
          AND pd.DiscountApplied != 0
          AND t.TxDate BETWEEN @StartDate AND @EndDate
    ),

    FinalData AS
    (
        SELECT * FROM JournalData
        UNION ALL
        SELECT * FROM DiscountData
    )

    SELECT 
        f.TxDate AS ShipDate,
        s.ShipRoute,
        p.PayeeName,
        f.SourceDocNumber AS SalesNumber,
        s.SalesRepId,
        f.SalesTotal,
        CAST(0 AS decimal) AS SalesPercent, -- calculated later
        f.Cost,
        CAST(0 AS decimal) AS MarginPercent, -- calculated later
        f.AccountId,
        c.AccountName
    INTO #DailySales
    FROM FinalData f
    INNER JOIN Sales s 
        ON s.SalesNumber = f.SourceDocNumber
    INNER JOIN Payee p 
        ON p.PayeeId = s.ShipId
    INNER JOIN Account c 
        ON c.AccountId = f.AccountId
    WHERE (@SalesRepId IS NULL OR s.SalesRepId = @SalesRepId);

    SELECT @TotalSales = SUM(ISNULL(SalesTotal,0))
    FROM #DailySales;

    UPDATE #DailySales
    SET 
        SalesPercent = CASE WHEN @TotalSales != 0 
                         THEN SalesTotal / @TotalSales 
                         ELSE 0 END,
        MarginPercent = CASE WHEN SalesTotal != 0 
                      THEN (SalesTotal - Cost) / SalesTotal 
                      ELSE 0 END;

    SELECT 
    ROW_NUMBER() OVER(ORDER BY ShipRoute, PayeeName, SalesNumber) AS Id,
    *
    FROM #DailySales
    ORDER BY ShipRoute, PayeeName, SalesNumber;
END

