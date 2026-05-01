-- Fix: TempSales LineId ordering for promo reward lines + delete handling
-- Date: 2026-04-16
-- Baseline: TempSalesReSeq_rollback.sql
--
-- Changes:
--   1. ORDER BY groups PROMO_REWARD lines after their owner
--   2. Deleted rows (ChangeStatus='D') get LineId=NULL and are excluded from renumbering

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER TRIGGER [dbo].[TRG_Update_TempSalesReSeq]
ON [dbo].[TempSales]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Find all (EmpId, PayeeId, SalesId) affected by this change
    ;WITH Changed AS
    (
        SELECT DISTINCT EmpId, PayeeId, SalesId
        FROM inserted
        WHERE EmpId IS NOT NULL
          AND PayeeId IS NOT NULL
          AND SalesId IS NOT NULL

        UNION

        SELECT DISTINCT EmpId, PayeeId, SalesId
        FROM deleted
        WHERE EmpId IS NOT NULL
          AND PayeeId IS NOT NULL
          AND SalesId IS NOT NULL
    )

    -- 2. NULL out LineId on deleted/struck rows so they don't participate in numbering
    UPDATE T
    SET T.LineId = NULL
    FROM TempSales T
    JOIN Changed C
      ON  C.EmpId   = T.EmpId
      AND C.PayeeId = T.PayeeId
      AND C.SalesId = T.SalesId
    WHERE T.ChangeStatus = 'D';

    -- 3. For those groups, recompute LineId = 1,2,3,... on active rows only
    ;WITH Changed AS
    (
        SELECT DISTINCT EmpId, PayeeId, SalesId
        FROM inserted
        WHERE EmpId IS NOT NULL
          AND PayeeId IS NOT NULL
          AND SalesId IS NOT NULL

        UNION

        SELECT DISTINCT EmpId, PayeeId, SalesId
        FROM deleted
        WHERE EmpId IS NOT NULL
          AND PayeeId IS NOT NULL
          AND SalesId IS NOT NULL
    ),
    Renumber AS
    (
        SELECT
            T.TempSalesId,
            ROW_NUMBER() OVER (
                PARTITION BY T.EmpId, T.PayeeId, T.SalesId
                ORDER BY
                    ISNULL(T.DisplaySort, T.LineId),
                    CASE WHEN T.CartLineType = 'MAIN' THEN 0 ELSE 1 END,
                    T.TempSalesId
            ) AS NewLineId
        FROM TempSales T
        JOIN Changed C
          ON  C.EmpId   = T.EmpId
          AND C.PayeeId = T.PayeeId
          AND C.SalesId = T.SalesId
        WHERE ISNULL(T.ChangeStatus, '') <> 'D'
    )
    UPDATE T
    SET T.LineId = R.NewLineId
    FROM TempSales T
    JOIN Renumber R
      ON T.TempSalesId = R.TempSalesId;

    -- 4. Refresh DisplaySort on PROMO_REWARD rows to match owner's new LineId
    ;WITH Changed4 AS
    (
        SELECT DISTINCT EmpId, PayeeId, SalesId
        FROM inserted
        WHERE EmpId IS NOT NULL
          AND PayeeId IS NOT NULL
          AND SalesId IS NOT NULL

        UNION

        SELECT DISTINCT EmpId, PayeeId, SalesId
        FROM deleted
        WHERE EmpId IS NOT NULL
          AND PayeeId IS NOT NULL
          AND SalesId IS NOT NULL
    )
    UPDATE reward
    SET reward.DisplaySort = owner.LineId
    FROM TempSales reward
    JOIN Changed4 C
      ON  C.EmpId   = reward.EmpId
      AND C.PayeeId = reward.PayeeId
      AND C.SalesId = reward.SalesId
    JOIN TempSales owner
      ON  owner.TempSalesId = ISNULL(reward.RootTempSalesId, reward.ParentTempSalesId)
    WHERE reward.CartLineType = 'PROMO_REWARD'
      AND ISNULL(reward.ChangeStatus, '') <> 'D'
      AND reward.DisplaySort <> owner.LineId;
END;
GO
