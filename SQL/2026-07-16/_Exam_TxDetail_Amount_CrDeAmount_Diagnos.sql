SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[_Exam_TxDetail_Amount_CrDeAmount_Diagnos]
    -- EXEC dbo._Exam_TxDetail_Amount_CrDeAmount_Diagnos @StartDate='2026-01-01', @EndDate='2026-07-16', @AccountCode='@ICREDIT';
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @AccountCode NVARCHAR(50) = NULL,
    @SourceDocType NVARCHAR(100) = NULL,
    @MaxRows INT = 500
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH FilteredRows AS
    (
        SELECT
            t.TxId,
            t.TxDate,
            t.SourceDocType,
            t.SourceDocNumber,
            td.TxDetailId,
            td.AccountId,
            a.AccountCode,
            a.AccountName,
            a.IsAccountDebit,
            td.Amount,
            td.CrDeAmount,
            CASE
                WHEN a.IsAccountDebit = 1 THEN -td.Amount
                ELSE td.Amount
            END AS ExpectedCrDeAmount
        FROM dbo.TransactionJournal t
        INNER JOIN dbo.TransactionJournalDetail td
            ON td.TxId = t.TxId
        INNER JOIN dbo.Account a
            ON a.AccountId = td.AccountId
        WHERE td.AccountId IS NOT NULL
          AND (@StartDate IS NULL OR t.TxDate >= @StartDate)
          AND (@EndDate IS NULL OR t.TxDate < DATEADD(DAY, 1, @EndDate))
          AND (@AccountCode IS NULL OR a.AccountCode = @AccountCode)
          AND (@SourceDocType IS NULL OR t.SourceDocType = @SourceDocType)
    ),
    MismatchRows AS
    (
        SELECT TOP (@MaxRows)
            fr.*
        FROM FilteredRows fr
        WHERE ISNULL(fr.CrDeAmount, 0) <> ISNULL(fr.ExpectedCrDeAmount, 0)
    ),
    MismatchTx AS
    (
        SELECT DISTINCT TxId
        FROM MismatchRows
    ),
    TxBalance AS
    (
        SELECT
            t.TxId,
            SUM(td.CrDeAmount) AS StoredCrDeBalance,
            SUM(CASE
                    WHEN a.IsAccountDebit = 1 THEN -td.Amount
                    ELSE td.Amount
                END) AS ExpectedCrDeBalance
        FROM MismatchTx mt
        INNER JOIN dbo.TransactionJournal t
            ON t.TxId = mt.TxId
        INNER JOIN dbo.TransactionJournalDetail td
            ON td.TxId = t.TxId
        INNER JOIN dbo.Account a
            ON a.AccountId = td.AccountId
        WHERE td.AccountId IS NOT NULL
        GROUP BY t.TxId
    )
    SELECT
        mr.TxId,
        mr.TxDate,
        mr.SourceDocType,
        mr.SourceDocNumber,
        mr.TxDetailId,
        mr.AccountCode,
        mr.AccountName,
        mr.IsAccountDebit,
        mr.Amount,
        mr.CrDeAmount,
        mr.ExpectedCrDeAmount,
        tb.StoredCrDeBalance,
        tb.ExpectedCrDeBalance,
        CASE
            WHEN ISNULL(mr.CrDeAmount, 0) = ISNULL(mr.ExpectedCrDeAmount, 0)
                THEN 'NoMismatch'
            WHEN ISNULL(tb.StoredCrDeBalance, 0) = 0
             AND ISNULL(tb.ExpectedCrDeBalance, 0) <> 0
                THEN 'AmountWrong_StoredCrDeBalances'
            WHEN ISNULL(tb.StoredCrDeBalance, 0) <> 0
             AND ISNULL(tb.ExpectedCrDeBalance, 0) = 0
                THEN 'CrDeAmountWrong_ExpectedCrDeBalances'
            ELSE 'BothOrAmbiguous'
        END AS Diagnosis
    FROM MismatchRows mr
    INNER JOIN TxBalance tb
        ON tb.TxId = mr.TxId
    ORDER BY
        mr.TxDate DESC,
        mr.TxId DESC,
        mr.TxDetailId
    OPTION (RECOMPILE);
END
GO
