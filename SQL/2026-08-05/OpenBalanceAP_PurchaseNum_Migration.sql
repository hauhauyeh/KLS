-- 2026-08-05 Slice 0 of plan/opening-balance-ap-import-template-v1.md
--
-- Two one-time changes to dbo.OpenBalanceAP, in one transaction:
--
--   1. PurchaseNum changes from INT to NVARCHAR(200) and starts holding the
--      client's own bill number instead of a KLS purchase number (D2).
--      INT only ever worked because the data came from the legacy KLS system,
--      whose purchase numbers were integers. 29 of the 166 live rows end up
--      non-numeric after this migration, and every one of those would be
--      silently nulled by the current import's TRY_CONVERT(INT, BillNumber).
--
--   2. PurchaseId is backfilled from the Purchase rows that already match on
--      PurchaseNumber + PayeeId, adopting them as opening AP source records
--      rather than recreating them later (D11 option a). Those purchases are
--      header-only and already paid; recreating them would discard real
--      payment history.
--
-- Order matters. The backup table is populated while PurchaseNum is still INT
-- so the join to Purchase.PurchaseNumber is a true int-to-int match, and it is
-- what makes the rollback possible at all.
--
-- Rollback: OpenBalanceAP_PurchaseNum_Migration_rollback.sql
-- Baseline: OpenBalanceAP_PurchaseNum_live_baseline.sql

SET XACT_ABORT ON;
GO

BEGIN TRAN;

------------------------------------------------------------------
-- Guards. Stop before touching anything if the shape is not what
-- the baseline recorded.
------------------------------------------------------------------

IF NOT EXISTS (
    SELECT 1
    FROM sys.columns c
    JOIN sys.types t ON t.user_type_id = c.user_type_id
    WHERE c.object_id = OBJECT_ID('dbo.OpenBalanceAP')
      AND c.name = 'PurchaseNum'
      AND t.name = 'int'
)
    THROW 51100, 'Expected dbo.OpenBalanceAP.PurchaseNum to be int. Capture a new baseline before deploying.', 1;

IF OBJECT_ID('dbo.OpenBalanceAP_PurchaseNum_Backup_20260805') IS NOT NULL
    THROW 51101, 'Backup table already exists. This migration has already run, or a previous attempt left state behind.', 1;

------------------------------------------------------------------
-- 1. Snapshot. Captures the original values AND the computed new
--    value, while PurchaseNum is still INT.
--
--    NewValue prefers the matched purchase's VendorDocNumber, which
--    is where the vendor's own bill number actually lives. Rows with
--    no match, or a match carrying no VendorDocNumber, keep their old
--    integer as text so nothing is lost.
------------------------------------------------------------------

CREATE TABLE dbo.OpenBalanceAP_PurchaseNum_Backup_20260805
(
    OpenAPId          INT             NOT NULL PRIMARY KEY,
    OldPurchaseNum    INT             NULL,
    OldPurchaseId     INT             NULL,
    NewValue          NVARCHAR(200)   NULL,
    MatchedPurchaseId INT             NULL
);

INSERT INTO dbo.OpenBalanceAP_PurchaseNum_Backup_20260805
    (OpenAPId, OldPurchaseNum, OldPurchaseId, NewValue, MatchedPurchaseId)
SELECT
    o.OpenAPId,
    o.PurchaseNum,
    o.PurchaseId,
    COALESCE(p.VendorDocNumber, CONVERT(NVARCHAR(200), o.PurchaseNum)),
    p.PurchaseId
FROM dbo.OpenBalanceAP o
LEFT JOIN dbo.Purchase p
    ON  p.PurchaseNumber = o.PurchaseNum
    AND p.PayeeId        = o.PayeeId;

IF NOT EXISTS (SELECT 1 FROM dbo.OpenBalanceAP_PurchaseNum_Backup_20260805)
    THROW 51102, 'Snapshot captured zero rows. Nothing to migrate; investigate before continuing.', 1;

GO

------------------------------------------------------------------
-- 2. The type change itself. Nothing indexes or constrains this
--    column, so no drops are needed.
------------------------------------------------------------------

ALTER TABLE dbo.OpenBalanceAP ALTER COLUMN PurchaseNum NVARCHAR(200) NULL;
GO

------------------------------------------------------------------
-- 3. Move the real bill numbers in.
------------------------------------------------------------------

UPDATE o
SET o.PurchaseNum = b.NewValue
FROM dbo.OpenBalanceAP o
JOIN dbo.OpenBalanceAP_PurchaseNum_Backup_20260805 b
    ON b.OpenAPId = o.OpenAPId;

------------------------------------------------------------------
-- 4. Adopt the existing purchases as opening AP source records.
--    After this, OpenBalanceAP.PurchaseId is what identifies an
--    opening purchase, per D1 as amended.
------------------------------------------------------------------

UPDATE o
SET o.PurchaseId = b.MatchedPurchaseId
FROM dbo.OpenBalanceAP o
JOIN dbo.OpenBalanceAP_PurchaseNum_Backup_20260805 b
    ON b.OpenAPId = o.OpenAPId
WHERE b.MatchedPurchaseId IS NOT NULL;

------------------------------------------------------------------
-- 5. Verify before committing. An unadopted row is not fatal to the
--    data, but it means a staging row has no source document, so stop
--    and look rather than half-migrating quietly.
------------------------------------------------------------------

IF EXISTS (SELECT 1 FROM dbo.OpenBalanceAP WHERE PurchaseId IS NULL)
    THROW 51103, 'At least one OpenBalanceAP row did not match a Purchase and was not adopted. Investigate before deploying.', 1;

COMMIT;
GO

------------------------------------------------------------------
-- Post-deploy check. Expected on KLS-2026 as captured 2026-08-05:
--   RowCnt 166, Adopted 166, NonNumeric 29, DuplicateGroups 0
------------------------------------------------------------------

SELECT
    COUNT(*)                                                        AS RowCnt,
    COUNT(PurchaseId)                                               AS Adopted,
    SUM(CASE WHEN TRY_CONVERT(INT, PurchaseNum) IS NULL AND PurchaseNum IS NOT NULL
             THEN 1 ELSE 0 END)                                     AS NonNumeric
FROM dbo.OpenBalanceAP;

SELECT COUNT(*) AS DuplicateGroups
FROM (
    SELECT PayeeId, PurchaseNum
    FROM dbo.OpenBalanceAP
    WHERE PurchaseNum IS NOT NULL
    GROUP BY PayeeId, PurchaseNum
    HAVING COUNT(*) > 1
) d;
GO
