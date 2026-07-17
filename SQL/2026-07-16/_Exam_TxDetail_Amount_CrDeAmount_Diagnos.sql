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

    ;WITH TxRows AS
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
            expected.CrDeAmount AS ExpectedCrDeAmount
        FROM dbo.TransactionJournal t
        INNER JOIN dbo.TransactionJournalDetail td
            ON td.TxId = t.TxId
        INNER JOIN dbo.Account a
            ON a.AccountId = td.AccountId
        CROSS APPLY dbo.Fn_CrDeAmount(td.AccountId, td.Amount) expected
        WHERE td.AccountId IS NOT NULL
          AND (@StartDate IS NULL OR t.TxDate >= @StartDate)
          AND (@EndDate IS NULL OR t.TxDate < DATEADD(DAY, 1, @EndDate))
          AND (@AccountCode IS NULL OR a.AccountCode = @AccountCode)
          AND (@SourceDocType IS NULL OR t.SourceDocType = @SourceDocType)
    ),
    TxBalance AS
    (
        SELECT
            tr.TxId,
            SUM(tr.CrDeAmount) AS StoredCrDeBalance,
            SUM(tr.ExpectedCrDeAmount) AS ExpectedCrDeBalance
        FROM TxRows tr
        GROUP BY tr.TxId
    )
    SELECT TOP (@MaxRows)
        tr.TxId,
        tr.TxDate,
        tr.SourceDocType,
        tr.SourceDocNumber,
        tr.TxDetailId,
        tr.AccountCode,
        tr.AccountName,
        tr.IsAccountDebit,
        tr.Amount,
        tr.CrDeAmount,
        tr.ExpectedCrDeAmount,
        tb.StoredCrDeBalance,
        tb.ExpectedCrDeBalance,
        CASE
            WHEN ISNULL(tr.CrDeAmount, 0) = ISNULL(tr.ExpectedCrDeAmount, 0)
                THEN 'NoMismatch'
            WHEN ISNULL(tb.StoredCrDeBalance, 0) = 0
             AND ISNULL(tb.ExpectedCrDeBalance, 0) <> 0
                THEN 'AmountWrong_StoredCrDeBalances'
            WHEN ISNULL(tb.StoredCrDeBalance, 0) <> 0
             AND ISNULL(tb.ExpectedCrDeBalance, 0) = 0
                THEN 'CrDeAmountWrong_ExpectedCrDeBalances'
            ELSE 'BothOrAmbiguous'
        END AS Diagnosis
    FROM TxRows tr
    INNER JOIN TxBalance tb
        ON tb.TxId = tr.TxId
    WHERE ISNULL(tr.CrDeAmount, 0) <> ISNULL(tr.ExpectedCrDeAmount, 0)
    ORDER BY
        tr.TxDate DESC,
        tr.TxId DESC,
        tr.TxDetailId;
END
GO
