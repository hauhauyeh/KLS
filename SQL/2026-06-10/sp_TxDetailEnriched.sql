SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('dbo.sp_TxDetailEnriched', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_TxDetailEnriched;
GO

CREATE PROCEDURE dbo.sp_TxDetailEnriched
    @AccountId INT
AS
BEGIN
    SET NOCOUNT ON;

    CREATE TABLE #Result
    (
        [TxDetailId] BIGINT NULL,
        [TxId] BIGINT NULL,
        [TxDate] DATE NULL,
        [SourceDocType] NVARCHAR(100) NULL,
        [SourceDocNumber] INT NULL,
        [Amount] DECIMAL(18,2) NULL,
        [IsLocked] BIT NULL DEFAULT ((0)),
        [BankDate] DATE NULL,
        [PayeeName] NVARCHAR(255) NULL,
        [ReferenceId] NVARCHAR(255) NULL,
        [PayeeId] INT NULL,
        [IsVoid] BIT,
        [PaymentMethod] NVARCHAR(255) NULL
    );

    -- Non-Payroll Service transactions
    INSERT INTO #Result
    (
        TxDetailId, TxId, TxDate, SourceDocType, SourceDocNumber, Amount,
        IsLocked, BankDate, PayeeName, ReferenceId, PayeeId, IsVoid, PaymentMethod
    )
    SELECT
        TD.TxDetailId,
        T.TxId,
        T.TxDate,
        T.SourceDocType,
        T.SourceDocNumber,
        ISNULL(TD.Amount, 0),
        T.IsLocked,
        T.BankDate,
        P.PayeeName,
        CASE
            WHEN T.SourceDocType = 'Transfer' THEN TF.ReferenceId
            WHEN T.SourceDocType IN ('Other Incoming Payment', 'Customer Refund') THEN CP.ReferenceId
            ELSE VP.ReferenceId
        END,
        TD.PayeeId,
        CASE
            WHEN T.SourceDocType NOT IN ('Deposit', 'Transfer', 'General Journal') THEN VP.IsVoid
            ELSE NULL
        END,
        CASE
            WHEN T.SourceDocType IN ('Other Incoming Payment', 'Customer Refund') THEN CP.PaymentMethod
            ELSE VP.PaymentMethod
        END
    FROM TransactionJournal AS T
    INNER JOIN TransactionJournalDetail AS TD
        ON T.TxId = TD.TxId
    LEFT JOIN Payee AS P
        ON P.PayeeId = TD.PayeeId
    LEFT JOIN TransferFund AS TF
        ON T.SourceDocType = 'Transfer'
       AND TF.TFNumber = T.SourceDocNumber
    LEFT JOIN CustomerPayment AS CP
        ON T.SourceDocType IN ('Other Incoming Payment', 'Customer Refund')
       AND CP.PaymentNumber = T.SourceDocNumber
    LEFT JOIN VendorPayment AS VP
        ON T.SourceDocType NOT IN ('Deposit', 'Transfer', 'General Journal', 'Other Incoming Payment', 'Customer Refund')
       AND VP.PaymentNumber = T.SourceDocNumber
    WHERE TD.AccountId = @AccountId
      AND T.SourceDocType <> 'Payroll Service';

    -- Payroll Service transactions (requires CTE + OUTER APPLY for per-employee resolution)
    ;WITH PayrollResolved AS
    (
        SELECT DISTINCT
            TD.TxDetailId,
            T.TxId,
            T.TxDate,
            T.SourceDocType,
            T.SourceDocNumber,
            TD.Amount,
            TD.PayeeId,
            TD.Notes,
            T.IsLocked AS TxIsLocked,
            T.BankDate AS TxBankDate,
            P.PayeeName,
            PSDMatch.ReferenceId,
            VPMatch.IsLocked AS VendorIsLocked,
            VPMatch.BankDate AS VendorBankDate,
            VPMatch.PaymentMethod
        FROM TransactionJournal AS T
        INNER JOIN TransactionJournalDetail AS TD
            ON T.TxId = TD.TxId
        LEFT JOIN Payee AS P
            ON P.PayeeId = TD.PayeeId
        OUTER APPLY
        (
            SELECT TOP (1)
                ps.VendorPaymentId,
                ps.ReferenceId
            FROM PayrollService AS p
            INNER JOIN PayrollServiceDetail AS ps
                ON p.PayrollServiceId = ps.PayrollServiceId
            WHERE p.PayrollNumber = T.SourceDocNumber
              AND ps.VendorPaymentId IS NOT NULL
              AND ps.PayeeId = TD.PayeeId
              AND
              (
                    (TD.Notes IS NOT NULL AND ps.ReferenceId = TD.Notes)
                 OR (TD.Notes IS NULL AND ps.ReferenceId IS NULL)
              )
        ) AS PSDMatch
        LEFT JOIN VendorPayment AS VPMatch
            ON VPMatch.VendorPaymentId = PSDMatch.VendorPaymentId
        WHERE TD.AccountId = @AccountId
          AND T.SourceDocType = 'Payroll Service'
    )
    INSERT INTO #Result
    (
        TxDetailId, TxId, TxDate, SourceDocType, SourceDocNumber, Amount,
        IsLocked, BankDate, PayeeName, ReferenceId, PayeeId, IsVoid, PaymentMethod
    )
    SELECT
        TxDetailId,
        TxId,
        TxDate,
        SourceDocType,
        SourceDocNumber,
        Amount,
        CASE
            WHEN PayeeId IS NOT NULL THEN ISNULL(VendorIsLocked, TxIsLocked)
            ELSE TxIsLocked
        END,
        CASE
            WHEN PayeeId IS NOT NULL THEN ISNULL(VendorBankDate, TxBankDate)
            ELSE TxBankDate
        END,
        PayeeName,
        ReferenceId,
        PayeeId,
        0,
        PaymentMethod
    FROM PayrollResolved;

    SELECT * FROM #Result;
END
GO
