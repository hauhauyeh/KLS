SET QUOTED_IDENTIFIER ON;
GO

ALTER PROCEDURE [dbo].[BankRecon_TxList]
    @BankReconId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PrevReconDate DATE;
    DECLARE @SysStartDate DATE;
    DECLARE @AccountId INT;
    DECLARE @StatementDate DATE;
    DECLARE @IsReconciled BIT;

    CREATE TABLE #TxTable
    (
        [AutoId] INT IDENTITY(1,1),
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

    -- Temp table to receive all enriched rows from shared SP
    CREATE TABLE #AllTx
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

    SELECT
        @SysStartDate = SettingValue
    FROM SystemSetting
    WHERE SettingKey = 'SYSTEM_START_DATE';

    SELECT
        @AccountId = AccountId,
        @StatementDate = StatementDate,
        @IsReconciled = IsReconciled
    FROM BankRecon
    WHERE BankReconId = @BankReconId;

    SELECT
        @PrevReconDate = MAX(StatementDate)
    FROM BankRecon
    WHERE StatementDate < @StatementDate
      AND AccountId = @AccountId;

    IF @PrevReconDate IS NULL
        SET @PrevReconDate = @SysStartDate;
    ELSE
        SET @PrevReconDate = DATEADD(DAY, 1, @PrevReconDate);

    -- Get all enriched transactions via shared SP
    INSERT INTO #AllTx EXEC dbo.sp_TxDetailEnriched @AccountId;

    -- Apply BankRecon-specific date filters
    INSERT INTO #TxTable (TxId, TxDate, SourceDocType, SourceDocNumber, Amount, IsLocked, BankDate, PayeeName, ReferenceId, PayeeId, IsVoid, PaymentMethod)
    SELECT TxId, TxDate, SourceDocType, SourceDocNumber, Amount, IsLocked, BankDate, PayeeName, ReferenceId, PayeeId, IsVoid, PaymentMethod
    FROM #AllTx
    WHERE (
            (TxDate BETWEEN @SysStartDate AND @StatementDate AND IsLocked = 0)
         OR (TxDate BETWEEN @PrevReconDate AND @StatementDate AND BankDate BETWEEN @PrevReconDate AND @StatementDate)
         OR (BankDate BETWEEN @PrevReconDate AND @StatementDate)
      );

    IF @IsReconciled = 1
    BEGIN
        SELECT *
        FROM #TxTable
        WHERE BankDate BETWEEN @PrevReconDate AND @StatementDate
        ORDER BY TxDate DESC, TxId DESC;
    END
    ELSE
    BEGIN
        SELECT *
        FROM #TxTable
        WHERE (IsVoid = 0 OR IsVoid IS NULL)
        ORDER BY TxDate DESC, TxId DESC;
    END
END
GO
