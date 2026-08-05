-- 2026-08-05 rollback for OpenBalanceAR_SalesNum_TypeChange.sql
--
-- Returns dbo.OpenBalanceAR.SalesNum to INT.
--
-- No snapshot table is needed here, unlike the AP rollback. The forward script
-- performs no backfill, so every value it leaves behind is the same digits it
-- started with and converts back cleanly.
--
-- The guard below is the real protection. A non-numeric SalesNum can only exist
-- if a real AR import has run since the type change and stored a client invoice
-- number such as INV-2023-001. Converting that back to int would silently destroy
-- client data, so this script refuses to run instead.
--
-- Baseline: OpenBalanceAR_SalesNum_live_baseline.sql

SET XACT_ABORT ON;
GO

BEGIN TRAN;

------------------------------------------------------------------
-- Guards, all before anything is written.
------------------------------------------------------------------

IF NOT EXISTS (
    SELECT 1
    FROM sys.columns c
    JOIN sys.types t ON t.user_type_id = c.user_type_id
    WHERE c.object_id = OBJECT_ID('dbo.OpenBalanceAR')
      AND c.name = 'SalesNum'
      AND t.name = 'nvarchar'
)
    THROW 51210, 'SalesNum is not nvarchar. The forward type change does not appear to be in effect.', 1;

IF EXISTS (
    SELECT 1
    FROM dbo.OpenBalanceAR
    WHERE SalesNum IS NOT NULL
      AND TRY_CONVERT(INT, SalesNum) IS NULL
)
    THROW 51211, 'A non-numeric SalesNum exists, so an AR import has stored real invoice numbers since the type change. Rolling back would destroy them. Resolve by hand.', 1;

GO

ALTER TABLE dbo.OpenBalanceAR ALTER COLUMN SalesNum INT NULL;
GO

COMMIT;
GO

SELECT
    t.name              AS TypeName,
    c.max_length        AS MaxLength,
    c.is_nullable
FROM sys.columns c
JOIN sys.types t ON t.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID('dbo.OpenBalanceAR')
  AND c.name = 'SalesNum';

SELECT COUNT(*) AS RowCnt, COUNT(SalesNum) AS SalesNumNotNull
FROM dbo.OpenBalanceAR;
GO
