/*
Purpose
=======
This utility procedure reviews transaction balance status for all
TransactionJournal rows on one business date, using the current committed
TransactionJournalDetail rows as the source of truth.

This procedure does not update any table.
It returns the recalculated rows and the affected TxId list for review.

How to use
==========
Single date:
EXEC dbo._exam_unbalance_tx_by_date @StartDate = '2026-05-06';

Date range:
EXEC dbo._exam_unbalance_tx_by_date @StartDate = '2026-05-01', @EndDate = '2026-05-06';
*/

CREATE OR ALTER PROC dbo._exam_unbalance_tx_by_date
    @StartDate DATE,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @EndDate IS NULL
        SET @EndDate = @StartDate;

    IF @EndDate < @StartDate
    BEGIN
        RAISERROR('EndDate cannot be earlier than StartDate.', 16, 1);
        RETURN;
    END

    IF OBJECT_ID('tempdb..#TargetTx') IS NOT NULL
        DROP TABLE #TargetTx;

    IF OBJECT_ID('tempdb..#TxRecalc') IS NOT NULL
        DROP TABLE #TxRecalc;

    /*
    Section 1. Capture the target transaction headers for the requested date or date range.
    */
    SELECT
        tj.TxId,
        tj.TxDate,
        tj.TxTime,
        tj.SourceDocOrder,
        tj.SourceDocType,
        tj.SourceDocNumber,
        tj.Notes,
        tj.IsLocked,
        tj.BankDate
    INTO #TargetTx
    FROM dbo.TransactionJournal AS tj
    WHERE tj.TxDate >= @StartDate
      AND tj.TxDate <= @EndDate;

    /*
    Section 2. Recalculate the detail-based balance for each target TxId.

    Business rule:
    - CrDeAmount is the normalized accounting-side amount.
    - A balanced transaction should have SUM(CrDeAmount) = 0.
    - We keep a half-cent tolerance so very small rounding noise is treated
      consistently during review.
    */
    SELECT
        t.TxId,
        t.TxDate,
        t.TxTime,
        t.SourceDocOrder,
        t.SourceDocType,
        t.SourceDocNumber,
        t.Notes,
        t.IsLocked,
        t.BankDate,
        COUNT(td.TxDetailId) AS DetailRowCount,
        SUM(ISNULL(td.Amount, 0)) AS TotalAmount,
        SUM(ISNULL(td.CrDeAmount, 0)) AS BalanceAmount,
        CASE
            WHEN ABS(SUM(ISNULL(td.CrDeAmount, 0))) < 0.005 THEN CAST(1 AS BIT)
            ELSE CAST(0 AS BIT)
        END AS IsBalanced
    INTO #TxRecalc
    FROM #TargetTx AS t
    LEFT JOIN dbo.TransactionJournalDetail AS td
        ON td.TxId = t.TxId
    GROUP BY
        t.TxId,
        t.TxDate,
        t.TxTime,
        t.SourceDocOrder,
        t.SourceDocType,
        t.SourceDocNumber,
        t.Notes,
        t.IsLocked,
        t.BankDate;

    /*
    Section 3. Return only unbalanced transaction rows for the requested date.
    */
    SELECT
        r.TxId,
        r.TxDate,
        r.TxTime,
        r.SourceDocOrder,
        r.SourceDocType,
        r.SourceDocNumber,
        r.Notes,
        r.IsLocked,
        r.BankDate,
        r.DetailRowCount,
        r.TotalAmount,
        r.BalanceAmount,
        r.IsBalanced
    FROM #TxRecalc AS r
    WHERE r.IsBalanced = 0
    ORDER BY
        ABS(r.BalanceAmount) DESC,
        r.TxId;

    /*
    Section 4. Return a compact TxId-only list for follow-up work.
    */
    SELECT
        r.TxId
    FROM #TxRecalc AS r
    WHERE r.IsBalanced = 0
    ORDER BY r.TxId;
END
