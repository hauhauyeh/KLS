-- 2026-08-13 DROP-SHIP-OPEN-INVOICE-GUARD: require posted Sales journal for positive invoice candidates.
CREATE   PROCEDURE [dbo].[BankFeed_GetOpenInvoices]   -- EXEC dbo.BankFeed_GetOpenInvoices @BankFeedTransactionId=1, @PayeeId=1, @Search=NULL, @Pageno=1, @Pagesize=25, @IsCount=0, @TotalCount=NULL
    @BankFeedTransactionId BIGINT,
    @PayeeId               INT,
    @Search                NVARCHAR(100) = NULL,
    @Pageno                INT           = 1,
    @Pagesize              INT           = 25,
    @IsCount               BIT           = 0,
    @TotalCount            INT           = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Validate the bank feed row is a usable money-in candidate
    DECLARE @Status         VARCHAR(20),
            @BankAmount     DECIMAL(18,2),
            @BankAccountId  INT;

    SELECT @Status        = bft.[Status],
           @BankAmount    = bft.Amount,
           @BankAccountId = bfa.AccountId
    FROM dbo.BankFeedTransaction AS bft
    LEFT JOIN dbo.BankFeedAccount AS bfa
        ON bfa.BankFeedAccountId = bft.BankFeedAccountId
    WHERE bft.BankFeedTransactionId = @BankFeedTransactionId;

    IF @Status IS NULL
        THROW 50505, 'Bank feed transaction not found.', 1;
    IF @Status <> 'Pending'
        THROW 50506, 'Only pending bank feed transactions can receive a payment.', 1;
    IF @BankAmount <= 0
        THROW 50507, 'Only money-in bank feed transactions can receive open invoices.', 1;
    IF @BankAccountId IS NULL
        THROW 50508, 'This bank feed row is not mapped to a GL account.', 1;
    IF @PayeeId IS NULL OR @PayeeId <= 0
        THROW 50509, 'Please select a customer.', 1;

    -- 2. Resolve the bill-to parent, exactly as CustomerPayment_Inject does
    DECLARE @BillId INT;

    SELECT TOP (1) @BillId = c.BillId
    FROM dbo.Customer AS c
    WHERE c.PayeeId = @PayeeId
      AND c.BillId IS NOT NULL;

    -- 3. Count pass - the paging contract the other lookups already use
    IF @IsCount = 1
    BEGIN
        SELECT @TotalCount = COUNT(*)
        FROM dbo.Sales AS s
        WHERE ((@BillId IS NOT NULL AND s.BillId = @BillId)
               OR (@BillId IS NULL AND s.ShipId = @PayeeId))
          AND (   (s.SalesTotal >= 0 AND s.AmountDue > 0 AND s.StageId >= 3
                   AND EXISTS (
                        SELECT 1
                        FROM dbo.TransactionJournal AS tj
                        WHERE tj.SourceDocType = 'Sales'
                          AND tj.SourceDocNumber = s.SalesNumber
                   ))                                                         -- invoice (D2)
               OR (s.SalesTotal < 0  AND s.AmountDue <> 0))                   -- credit memo (D11)
          AND (@Search IS NULL
               OR CAST(s.SalesNumber AS VARCHAR(50)) LIKE '%' + @Search + '%');

        RETURN;
    END;

    -- 4. Page pass. Invoices first (oldest due first), then credit memos.
    SELECT
        s.SalesId,
        s.SalesNumber,
        s.ShipId                                            AS PayeeId,
        ps.PayeeName                                        AS CustomerName,
        pb.PayeeName                                        AS BillName,
        CAST(s.SalesDate AS DATE)                           AS SalesDate,  -- datetime in Sales; DateOnly in the model
        s.DueDate,
        s.SalesTotal,
        s.AmountDue,
        CAST(CASE WHEN s.SalesTotal < 0 THEN 1 ELSE 0 END AS BIT) AS IsCreditMemo
    FROM dbo.Sales AS s
    JOIN dbo.Payee AS ps ON ps.PayeeId = s.ShipId
    JOIN dbo.Payee AS pb ON pb.PayeeId = s.BillId
    WHERE ((@BillId IS NOT NULL AND s.BillId = @BillId)
           OR (@BillId IS NULL AND s.ShipId = @PayeeId))
      AND (   (s.SalesTotal >= 0 AND s.AmountDue > 0 AND s.StageId >= 3
               AND EXISTS (
                    SELECT 1
                    FROM dbo.TransactionJournal AS tj
                    WHERE tj.SourceDocType = 'Sales'
                      AND tj.SourceDocNumber = s.SalesNumber
               ))
           OR (s.SalesTotal < 0  AND s.AmountDue <> 0))
      AND (@Search IS NULL
           OR CAST(s.SalesNumber AS VARCHAR(50)) LIKE '%' + @Search + '%')
    ORDER BY CASE WHEN s.SalesTotal < 0 THEN 1 ELSE 0 END, s.DueDate, s.SalesId
    OFFSET (@Pagesize * (@Pageno - 1)) ROWS
    FETCH NEXT @Pagesize ROWS ONLY;
END


