SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- GeneralJournal_OBAccount
-- Source-captured from KLS-2026 on 2026-08-04.
-- Posts the Opening Balance Account / Trial Balance journal.
--
-- 2026-08-04: OB Account uses reserved GJNumber 0. Normal manual
-- General Journals use positive sequence numbers; GJNumber 1 must not
-- be reserved or deleted by opening-balance posting.
-- ============================================================

CREATE OR ALTER PROCEDURE [dbo].[GeneralJournal_OBAccount]
AS
BEGIN

    SET NOCOUNT ON;

    DELETE FROM GeneralJournal WHERE GJNumber = 0

    DECLARE @GjNum INT = 0
    DECLARE @GjId INT
    DECLARE @TxId BIGINT

    DECLARE @BeginDate DATE

    DECLARE @MaxRow INT
    DECLARE @RowNum INT = 1

    DECLARE @AccountId INT
    DECLARE @AccountCode NVARCHAR(50)
    DECLARE @AccountBalance DECIMAL(18,2)

    DECLARE @CrDeAmt DECIMAL(18,2)
    DECLARE @DebitAmt DECIMAL(18,2)
    DECLARE @CreditAmt DECIMAL(18,2)

    DECLARE @OBECode NVARCHAR(50)='@OBE'
    DECLARE @OBEAccountId INT

    DECLARE @OBEAmount DECIMAL(18,2)
    DECLARE @OBECrDeAmt DECIMAL(18,2)
    DECLARE @OBEDebitAmt DECIMAL(18,2)
    DECLARE @OBECreditAmt DECIMAL(18,2)
    DECLARE @IsDebit BIT

    SELECT @BeginDate = SettingValue
    FROM SystemSetting
    WHERE SettingKey='SYSTEM_START_DATE'


    SELECT @OBEAccountId = AccountId
    FROM Account
    WHERE AccountCode=@OBECode


    INSERT INTO [dbo].[GeneralJournal]
           ([GJNumber]
           ,[GjDate]
           ,[TotalDebitAmount]
           ,[TotalCreditAmount]
           ,[Notes])
     VALUES
           (@GjNum
           ,@BeginDate
           ,0
           ,0
           ,'Opening Balance - Balance Sheet Account')

    SET @GjId = SCOPE_IDENTITY()


    INSERT INTO [dbo].[TransactionJournal]
           ([TxDate]
           ,[TxTime]
           ,[SourceDocOrder]
           ,[SourceDocType]
           ,[SourceDocNumber]
           ,[Notes])
     VALUES
           (@BeginDate
           ,GETUTCDATE()
           ,100
           ,'General Journal'
           ,@GjNum
           ,'Opening Balance - Balance Sheet Account')

    SET @TxId = SCOPE_IDENTITY()



    DECLARE @TempTable TABLE(
        [AutoId] INT IDENTITY(1,1),
        [AccountId] INT,
        [AccountCode] NVARCHAR(50),
        [AccountBalance] DECIMAL(18,2)
    )

    INSERT INTO @TempTable
    SELECT AccountId,AccountCode,ISNULL(Balance,0)
    FROM OpenBalanceAccount
    WHERE AccountCode!='@OBE'


    SELECT @MaxRow=COUNT(*) FROM @TempTable


    WHILE @RowNum<=@MaxRow
    BEGIN

        SELECT 
            @AccountId=AccountId,
            @AccountCode=AccountCode,
            @AccountBalance=AccountBalance
        FROM @TempTable
        WHERE AutoId=@RowNum


        IF @AccountCode IN ('@AR','@ARE','@AP','@INV')
            SET @AccountBalance=0


        IF ISNULL(@AccountBalance,0)<>0
        BEGIN
            SET @CrDeAmt=0
            EXEC Fn_Adjust_CrDeAmount @AccountCode,@AccountBalance,@CrDeAmt OUTPUT

            SET @CreditAmt = CASE WHEN @CrDeAmt > 0 THEN @CrDeAmt ELSE 0 END
            SET @DebitAmt  = CASE WHEN @CrDeAmt <= 0 THEN ABS(@CrDeAmt) ELSE 0 END

            INSERT INTO [dbo].[GeneralJournalDetail]
               ([GJId]
               ,[AccountId]
               ,[PayeeId]
               ,[Amount]
               ,[CrDeAmount]
               ,[DebitAmount]
               ,[CreditAmount])
            VALUES
               (@GjId
               ,@AccountId
               ,NULL
               ,@AccountBalance
               ,@CrDeAmt
               ,@DebitAmt
               ,@CreditAmt)

            SELECT @IsDebit=IsAccountDebit FROM Account WHERE AccountId=@AccountId

            IF @IsDebit=1
                SET @OBEAmount = @AccountBalance
            ELSE
                SET @OBEAmount = -@AccountBalance

            
            SET @OBECrDeAmt=0
            EXEC Fn_Adjust_CrDeAmount @OBECode,@OBEAmount,@OBECrDeAmt OUTPUT

            SET @OBECreditAmt = CASE WHEN @OBECrDeAmt > 0 THEN @OBECrDeAmt ELSE 0 END
            SET @OBEDebitAmt  = CASE WHEN @OBECrDeAmt <= 0 THEN ABS(@OBECrDeAmt) ELSE 0 END

            INSERT INTO [dbo].[GeneralJournalDetail]
               ([GJId]
               ,[AccountId]
               ,[PayeeId]
               ,[Amount]
               ,[CrDeAmount]
               ,[DebitAmount]
               ,[CreditAmount])
            VALUES
               (@GjId
               ,@OBEAccountId
               ,NULL
               ,@OBEAmount
               ,@OBECrDeAmt
               ,@OBEDebitAmt
               ,@OBECreditAmt)
            

            -- TransactionJournalDetail (Account)
            INSERT INTO dbo.TransactionJournalDetail
               (TxId, AccountId, PayeeId, Amount, CrDeAmount)
            VALUES
               (@TxId, @AccountId, NULL, @AccountBalance, @CrDeAmt)

             -- TransactionJournalDetail (OBE)
            INSERT INTO dbo.TransactionJournalDetail
               (TxId, AccountId, PayeeId, Amount, CrDeAmount)
            VALUES
               (@TxId, @OBEAccountId, NULL, @OBEAmount, @OBECrDeAmt)
        END


        SET @RowNum = @RowNum + 1
    END


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
    WHERE gj.GJId=@GjId

END
GO
