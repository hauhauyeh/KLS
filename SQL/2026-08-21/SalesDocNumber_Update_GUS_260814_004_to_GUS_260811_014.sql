SET XACT_ABORT ON;
SET NOCOUNT ON;

DECLARE @OldSalesDocNumber NVARCHAR(50) = N'GUS-260814-004';
DECLARE @NewSalesDocNumber NVARCHAR(50) = N'GUS-260811-014';
DECLARE @SalesId INT;

SELECT @SalesId = SalesId
FROM dbo.Sales
WHERE SalesDocNumber = @OldSalesDocNumber;

IF @SalesId IS NULL
    THROW 51001, 'Old SalesDocNumber was not found.', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.Sales
    WHERE SalesDocNumber = @NewSalesDocNumber
      AND SalesId <> @SalesId
)
    THROW 51002, 'New SalesDocNumber already exists on another Sales row.', 1;

BEGIN TRANSACTION;

UPDATE dbo.Sales
SET
    SalesDocNumber = @NewSalesDocNumber,
    UpdatedAt = GETUTCDATE()
WHERE SalesId = @SalesId
  AND SalesDocNumber = @OldSalesDocNumber;

IF @@ROWCOUNT <> 1
    THROW 51003, 'SalesDocNumber update did not affect exactly one row.', 1;

COMMIT TRANSACTION;

SELECT
    SalesId,
    SalesNumber,
    SalesDocNumber,
    StageId,
    IsLocked
FROM dbo.Sales
WHERE SalesId = @SalesId;
