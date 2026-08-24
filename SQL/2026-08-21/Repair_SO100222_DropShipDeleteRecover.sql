SET XACT_ABORT ON;
SET NOCOUNT ON;

DECLARE @SalesNumber INT = 100222;
DECLARE @ExpectedSalesId INT = 421;
DECLARE @SalesId INT;
DECLARE @PurchaseCount INT;
DECLARE @JournalCount INT;

SELECT
    @SalesId = s.SalesId
FROM dbo.Sales s
WHERE s.SalesNumber = @SalesNumber;

IF @SalesId IS NULL
    THROW 50000, 'SO100222 was not found.', 1;

IF @SalesId <> @ExpectedSalesId
    THROW 50000, 'SO100222 SalesId does not match expected repair target.', 1;

SELECT
    @PurchaseCount = COUNT(*)
FROM dbo.Purchase p
WHERE p.DropShipSalesId = @SalesId;

IF @PurchaseCount > 0
    THROW 50000, 'SO100222 still has linked drop-ship Purchase rows. Stop repair.', 1;

SELECT
    @JournalCount = COUNT(*)
FROM dbo.TransactionJournal t
WHERE t.SourceDocType = 'Sales'
  AND t.SourceDocNumber = @SalesNumber;

IF @JournalCount > 0
    THROW 50000, 'SO100222 still has Sales journal rows. Stop repair.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.Sales s
    WHERE s.SalesId = @SalesId
      AND s.SalesNumber = @SalesNumber
      AND ISNULL(s.IsDropShip, 0) = 0
      AND s.DropShipPurchaseId IS NULL
      AND s.StageId = 2
)
    THROW 50000, 'SO100222 is not in the expected bad recovery state. Stop repair.', 1;

BEGIN TRANSACTION;

SELECT
    'Before' AS CheckName,
    s.SalesId,
    s.SalesNumber,
    s.StageId,
    s.IsDropShip,
    s.DropShipPurchaseId,
    s.ShipDate
FROM dbo.Sales s
WHERE s.SalesId = @SalesId;

SELECT
    'Before' AS CheckName,
    COUNT(*) AS DetailRows,
    SUM(CASE WHEN sd.ShipQty IS NOT NULL OR sd.BillQty IS NOT NULL OR sd.BaseShipQty IS NOT NULL OR sd.BaseBillQty IS NOT NULL THEN 1 ELSE 0 END) AS QtyRows
FROM dbo.SalesDetail sd
WHERE sd.SalesId = @SalesId
  AND sd.LineType = 'I'
  AND sd.ItemId IS NOT NULL;

UPDATE dbo.Sales
SET
    StageId = 0,
    IsDropShip = 0,
    DropShipPurchaseId = NULL,
    UpdatedAt = SYSUTCDATETIME()
WHERE SalesId = @SalesId
  AND SalesNumber = @SalesNumber
  AND ISNULL(IsDropShip, 0) = 0
  AND DropShipPurchaseId IS NULL
  AND StageId = 2;

IF @@ROWCOUNT <> 1
    THROW 50000, 'SO100222 header repair updated unexpected row count.', 1;

UPDATE dbo.SalesDetail
SET
    ShipQty = NULL,
    BillQty = NULL,
    BaseShipQty = NULL,
    BaseBillQty = NULL
WHERE SalesId = @SalesId
  AND LineType = 'I'
  AND ItemId IS NOT NULL;

SELECT
    'After' AS CheckName,
    s.SalesId,
    s.SalesNumber,
    s.StageId,
    s.IsDropShip,
    s.DropShipPurchaseId,
    s.ShipDate
FROM dbo.Sales s
WHERE s.SalesId = @SalesId;

SELECT
    'After' AS CheckName,
    COUNT(*) AS DetailRows,
    SUM(CASE WHEN sd.ShipQty IS NOT NULL OR sd.BillQty IS NOT NULL OR sd.BaseShipQty IS NOT NULL OR sd.BaseBillQty IS NOT NULL THEN 1 ELSE 0 END) AS QtyRows
FROM dbo.SalesDetail sd
WHERE sd.SalesId = @SalesId
  AND sd.LineType = 'I'
  AND sd.ItemId IS NOT NULL;

COMMIT TRANSACTION;
