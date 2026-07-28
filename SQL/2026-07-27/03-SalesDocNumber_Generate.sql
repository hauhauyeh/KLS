SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- BEGIN TRANSACTION; DECLARE @SalesDocNumber NVARCHAR(50); EXEC dbo.SalesDocNumber_Generate @DocType='SO', @SalesDocNumber=@SalesDocNumber OUTPUT; SELECT @SalesDocNumber AS SalesDocNumber; ROLLBACK TRANSACTION;
CREATE OR ALTER PROCEDURE [dbo].[SalesDocNumber_Generate]
    @DocType CHAR(2) = 'SO',
    @SalesDocNumber NVARCHAR(50) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @@TRANCOUNT = 0
    BEGIN
        THROW 51003, 'SalesDocNumber_Generate must be called inside a transaction.', 1;
    END;

    SET @DocType = UPPER(LTRIM(RTRIM(ISNULL(@DocType, 'SO'))));

    DECLARE @CompanyCode NVARCHAR(20);
    DECLARE @DocDate DATE = CAST(GETDATE() AS DATE);
    DECLARE @Seq INT;
    DECLARE @SeqText VARCHAR(20);
    DECLARE @DateText CHAR(6) = CONVERT(CHAR(6), @DocDate, 12);

    SELECT TOP (1)
        @CompanyCode = UPPER(LTRIM(RTRIM(CompanyCode)))
    FROM dbo.Company
    ORDER BY CompanyId;

    IF NULLIF(@CompanyCode, '') IS NULL
    BEGIN
        THROW 51001, 'Company.CompanyCode is required to generate SalesDocNumber.', 1;
    END;

    IF LEN(@CompanyCode) > 10 OR PATINDEX('%[^A-Z0-9]%', @CompanyCode) > 0
    BEGIN
        THROW 51002, 'Company.CompanyCode must be 1-10 letters/numbers with no spaces.', 1;
    END;

    UPDATE dbo.SalesDocNumberCounter WITH (UPDLOCK, HOLDLOCK)
    SET
        @Seq = LastSeq = LastSeq + 1,
        UpdatedAt = GETUTCDATE()
    WHERE DocDate = @DocDate;

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO dbo.SalesDocNumberCounter (DocDate, LastSeq)
        VALUES (@DocDate, 1);

        SET @Seq = 1;
    END;

    SET @SeqText = CASE
        WHEN @Seq < 1000 THEN RIGHT('000' + CONVERT(VARCHAR(20), @Seq), 3)
        ELSE CONVERT(VARCHAR(20), @Seq)
    END;

    SET @SalesDocNumber =
        @CompanyCode + '-' +
        @DateText + '-' +
        @SeqText +
        CASE WHEN @DocType = 'CM' THEN '-CM' ELSE '' END;
END;
GO
