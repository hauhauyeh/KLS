SET XACT_ABORT ON;
GO

BEGIN TRAN;

UPDATE im
SET IsPrimary = 0
FROM ItemImage im
WHERE im.ItemId IN (SELECT ItemId FROM Item);

INSERT INTO ItemImage (
    ItemId,
    ImageIndex,
    OriginalExtension,
    SortOrder,
    IsPrimary,
    IsProcessed,
    IsProcessing,
    Has300,
    Has1200,
    Has2000,
    HasNoBg300,
    HasNoBg1200,
    CreatedAt
)
SELECT
    i.ItemId,
    101,
    '.png',
    1,
    1,
    0,
    0,
    1,
    1,
    0,
    0,
    0,
    GETDATE()
FROM Item i
WHERE NOT EXISTS (
    SELECT 1
    FROM ItemImage im
    WHERE im.ItemId = i.ItemId
      AND im.ImageIndex = 101
);

UPDATE im
SET
    IsPrimary = 1,
    Has300 = 1,
    Has1200 = 1,
    SortOrder = 1
FROM ItemImage im
WHERE im.ImageIndex = 101
  AND im.ItemId IN (SELECT ItemId FROM Item);

COMMIT;
GO

SELECT
    (SELECT COUNT(*) FROM Item) AS Items,
    (SELECT COUNT(*)
     FROM Item i
     WHERE EXISTS (
        SELECT 1
        FROM ItemImage im
        WHERE im.ItemId = i.ItemId
          AND im.IsPrimary = 1
          AND im.Has300 = 1
     )) AS ItemsWithPrimaryImage,
    (SELECT COUNT(*)
     FROM Item i
     WHERE NOT EXISTS (
        SELECT 1
        FROM ItemImage im
        WHERE im.ItemId = i.ItemId
          AND im.IsPrimary = 1
          AND im.Has300 = 1
     )) AS ItemsMissingPrimaryImage;
GO
