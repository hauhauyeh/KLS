CREATE   PROCEDURE [dbo].[GeneralJournal_OBAR]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @GjNum INT = -1;
    DECLARE @GjId INT;
    DECLARE @TxId BIGINT;

    DECLARE @BeginDate DATE;
    DECLARE @MaxRow INT;
    DECLARE @RowNum INT = 1;

    DECLARE @ARCode NVARCHAR(50) = '@AR';
    DECLARE @ARAccountId INT;
    DECLARE @OBECode NVARCHAR(50) = '@OBE';
    DECLARE @OBEAccountId INT;

    DECLARE @PayeeId INT;
    DECLARE @Amount DECIMAL(18,2);

    DECLARE @ARAmount DECIMAL(18,2);
    DECLARE @ARCrDeAmt DECIMAL(18,2);
    DECLARE @ARDebitAmt DECIMAL(18,2);
    DECLARE @ARCreditAmt DECIMAL(18,2);

    DECLARE @OBEAmount DECIMAL(18,2);
    DECLARE @OBECrDeAmt DECIMAL(18,2);
    DECLARE @OBEDebitAmt DECIMAL(18,2);
    DECLARE @OBECreditAmt DECIMAL(18,2);

    -- Begin Date
    SELECT @BeginDate = SettingValue
    FROM SystemSetting
    WHERE SettingKey='SYSTEM_START_DATE';

    -- AccountIds
    SELECT @ARAccountId = AccountId
    FROM Account
    WHERE AccountCode = @ARCode;

    SELECT @OBEAccountId = AccountId
    FROM Account
    WHERE AccountCode = @OBECode;

    -- GJ Header
    INSERT INTO dbo.GeneralJournal
        (GJNumber, GjDate, TotalDebitAmount, TotalCreditAmount, Notes)
    VALUES
        (@GjNum, @BeginDate, 0, 0, 'Opening Balance - AR');

    SET @GjId = SCOPE_IDENTITY();

    -- Tx Header
    INSERT INTO dbo.TransactionJournal
        (TxDate, TxTime, SourceDocOrder, SourceDocType, SourceDocNumber, Notes)
    VALUES
        (@BeginDate, GETUTCDATE(), 100, 'General Journal', @GjNum, 'Opening Balance - AR');

    SET @TxId = SCOPE_IDENTITY();

    -- Temp from OpenBalanceAR (group by PayeeId so you post 1 line per customer/vendor)
    DECLARE @TempTable TABLE(
        AutoId INT IDENTITY(1,1),
        PayeeId INT,
        Amount DECIMAL(18,2)
    );

    INSERT INTO @TempTable (PayeeId, Amount)
    SELECT
        PayeeId,
        SUM(ISNULL(Amount,0)) AS Amount
    FROM dbo.OpenBalanceAR
    GROUP BY PayeeId
    HAVING SUM(ISNULL(Amount,0)) <> 0;

    SELECT @MaxRow = COUNT(*) FROM @TempTable;

    WHILE @RowNum <= @MaxRow
    BEGIN
        SELECT
            @PayeeId = PayeeId,
            @Amount  = Amount
        FROM @TempTable
        WHERE AutoId = @RowNum;

        ------------------------------------------------------------------
        -- AR line
        ------------------------------------------------------------------
        SET @ARAmount = @Amount;

        SET @ARCrDeAmt = 0;
        EXEC Fn_Adjust_CrDeAmount @ARCode, @ARAmount, @ARCrDeAmt OUTPUT;

        SET @ARCreditAmt = CASE WHEN @ARCrDeAmt > 0 THEN @ARCrDeAmt ELSE 0 END;
        SET @ARDebitAmt  = CASE WHEN @ARCrDeAmt <= 0 THEN ABS(@ARCrDeAmt) ELSE 0 END;

        INSERT INTO dbo.GeneralJournalDetail
            (GJId, AccountId, PayeeId, Amount, CrDeAmount, DebitAmount, CreditAmount)
        VALUES
            (@GjId, @ARAccountId, @PayeeId, @ARAmount, @ARCrDeAmt, @ARDebitAmt, @ARCreditAmt);

        ------------------------------------------------------------------
        -- OBE balancing line (opposite amount)
        ------------------------------------------------------------------
        SET @OBEAmount = @Amount;

        SET @OBECrDeAmt = 0;
        EXEC Fn_Adjust_CrDeAmount @OBECode, @OBEAmount, @OBECrDeAmt OUTPUT;

        SET @OBECreditAmt = CASE WHEN @OBECrDeAmt > 0 THEN @OBECrDeAmt ELSE 0 END;
        SET @OBEDebitAmt  = CASE WHEN @OBECrDeAmt <= 0 THEN ABS(@OBECrDeAmt) ELSE 0 END;

        INSERT INTO dbo.GeneralJournalDetail
            (GJId, AccountId, PayeeId, Amount, CrDeAmount, DebitAmount, CreditAmount)
        VALUES
            (@GjId, @OBEAccountId, @PayeeId, @OBEAmount, @OBECrDeAmt, @OBEDebitAmt, @OBECreditAmt);

        ------------------------------------------------------------------
        -- TransactionJournalDetail (minimal fields only)
        ------------------------------------------------------------------
        INSERT INTO dbo.TransactionJournalDetail
            (TxId, AccountId, PayeeId, Amount, CrDeAmount)
        VALUES
            (@TxId, @ARAccountId,  @PayeeId, @ARAmount,  @ARCrDeAmt);

        INSERT INTO dbo.TransactionJournalDetail
            (TxId, AccountId, PayeeId, Amount, CrDeAmount)
        VALUES
            (@TxId, @OBEAccountId, @PayeeId, @OBEAmount, @OBECrDeAmt);

        SET @RowNum = @RowNum + 1;
    END

    -- Update totals
    UPDATE gj
    SET
        TotalDebitAmount  = x.TotalDebit,
        TotalCreditAmount = x.TotalCredit
    FROM dbo.GeneralJournal gj
    CROSS APPLY
    (
        SELECT
            SUM(ISNULL(DebitAmount,0))  AS TotalDebit,
            SUM(ISNULL(CreditAmount,0)) AS TotalCredit
        FROM dbo.GeneralJournalDetail
        WHERE GJId=@GjId
    ) x
    WHERE gj.GJId=@GjId;
END

