-- 2026-08-05 Slice 0 of plan/opening-balance-ar-salesnum-type-v1.md
--
-- Widens dbo.OpenBalanceAR.SalesNum from INT to NVARCHAR(50) so it can hold the
-- client's own invoice number from their previous system. An invoice number such
-- as INV-2023-001 cannot be stored in an int at all, and the AP half of this work
-- proved the case with real data: 29 of 166 vendor bill numbers were non-numeric.
--
-- NVARCHAR(50), not the 200 used for AP: the same value also lands in
-- Sales.SalesDocNumber, which is nvarchar(50). A wider staging column would let an
-- over-long invoice number pass this write and fail the Sales write.
--
-- No backfill. Unlike the AP change there is no better value to copy in: every
-- matched Sales row has SalesDocNumber NULL. Existing values simply become text.
--
-- Rollback: OpenBalanceAR_SalesNum_TypeChange_rollback.sql
-- Baseline: OpenBalanceAR_SalesNum_live_baseline.sql

SET XACT_ABORT ON;
GO

BEGIN TRAN;

------------------------------------------------------------------
-- Guards. Stop before changing anything if the table is not in the
-- shape the baseline recorded.
------------------------------------------------------------------

IF NOT EXISTS (
    SELECT 1
    FROM sys.columns c
    JOIN sys.types t ON t.user_type_id = c.user_type_id
    WHERE c.object_id = OBJECT_ID('dbo.OpenBalanceAR')
      AND c.name = 'SalesNum'
      AND t.name = 'int'
)
    THROW 51200, 'Expected dbo.OpenBalanceAR.SalesNum to be int. Capture a new baseline before deploying.', 1;

-- Anything longer than 50 characters could not survive the change, and would also
-- not fit Sales.SalesDocNumber later. The baseline says the longest is 7 digits.
IF EXISTS (
    SELECT 1
    FROM dbo.OpenBalanceAR
    WHERE SalesNum IS NOT NULL
      AND LEN(CONVERT(NVARCHAR(50), SalesNum)) > 50
)
    THROW 51201, 'A SalesNum value is longer than 50 characters. Stop and review before widening.', 1;

GO

------------------------------------------------------------------
-- The change. Nothing indexes or constrains this column, so no
-- drops are required.
------------------------------------------------------------------

ALTER TABLE dbo.OpenBalanceAR ALTER COLUMN SalesNum NVARCHAR(50) NULL;
GO

COMMIT;
GO

------------------------------------------------------------------
-- Post-deploy check. Expected on KLS-2026 as captured 2026-08-05:
--   TypeName nvarchar, Chars 50, RowCnt 1618, SalesNumNotNull 1618,
--   NonNumeric 0 (nothing in this script creates a non-numeric value).
------------------------------------------------------------------

SELECT
    t.name              AS TypeName,
    c.max_length / 2    AS Chars,
    c.is_nullable
FROM sys.columns c
JOIN sys.types t ON t.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID('dbo.OpenBalanceAR')
  AND c.name = 'SalesNum';

SELECT
    COUNT(*)                                                            AS RowCnt,
    COUNT(SalesNum)                                                     AS SalesNumNotNull,
    SUM(CASE WHEN SalesNum IS NOT NULL AND TRY_CONVERT(INT, SalesNum) IS NULL
             THEN 1 ELSE 0 END)                                         AS NonNumeric
FROM dbo.OpenBalanceAR;
GO
