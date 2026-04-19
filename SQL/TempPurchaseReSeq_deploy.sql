-- Fix: TempPurchase LineId resequencing on update/delete
-- Date: 2026-04-16
-- Baseline: TempPurchaseReSeq_rollback.sql
--
-- Changes:
--   1. Deleted rows (ChangeStatus='D') get LineId=NULL and are excluded from renumbering
--   2. Active rows are renumbered by LineId, TempPurchaseId

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER TRIGGER [dbo].[TRG_Update_TempPurchaseReSeq]
ON [dbo].[TempPurchase]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Changed AS
    (
        SELECT DISTINCT EmpId, PayeeId, PurchaseId
        FROM inserted
        WHERE EmpId IS NOT NULL
          AND PayeeId IS NOT NULL
          AND PurchaseId IS NOT NULL

        UNION

        SELECT DISTINCT EmpId, PayeeId, PurchaseId
        FROM deleted
        WHERE EmpId IS NOT NULL
          AND PayeeId IS NOT NULL
          AND PurchaseId IS NOT NULL
    )
    UPDATE T
    SET T.LineId = NULL
    FROM TempPurchase T
    JOIN Changed C
      ON C.EmpId = T.EmpId
     AND C.PayeeId = T.PayeeId
     AND C.PurchaseId = T.PurchaseId
    WHERE ISNULL(T.ChangeStatus, '') = 'D';

    ;WITH Changed AS
    (
        SELECT DISTINCT EmpId, PayeeId, PurchaseId
        FROM inserted
        WHERE EmpId IS NOT NULL
          AND PayeeId IS NOT NULL
          AND PurchaseId IS NOT NULL

        UNION

        SELECT DISTINCT EmpId, PayeeId, PurchaseId
        FROM deleted
        WHERE EmpId IS NOT NULL
          AND PayeeId IS NOT NULL
          AND PurchaseId IS NOT NULL
    ),
    Renumber AS
    (
        SELECT
            T.TempPurchaseId,
            ROW_NUMBER() OVER
            (
                PARTITION BY T.EmpId, T.PayeeId, T.PurchaseId
                ORDER BY T.LineId, T.TempPurchaseId
            ) AS NewLineId
        FROM TempPurchase T
        JOIN Changed C
          ON C.EmpId = T.EmpId
         AND C.PayeeId = T.PayeeId
         AND C.PurchaseId = T.PurchaseId
        WHERE ISNULL(T.ChangeStatus, '') <> 'D'
    )
    UPDATE T
    SET T.LineId = R.NewLineId
    FROM TempPurchase T
    JOIN Renumber R
      ON R.TempPurchaseId = T.TempPurchaseId;
END;
GO
