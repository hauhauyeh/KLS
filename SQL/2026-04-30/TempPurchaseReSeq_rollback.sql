-- Baseline dumped from live DB: 2026-04-17
-- Rollback: restores TRG_Update_TempPurchaseReSeq to pre-feature state

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
    -- 1. Find all (EmpId, PayeeId, PurchaseId) affected by this change
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
    -- 2. For those groups, recompute LineId = 1,2,3,... 
    Renumber AS
    (
        SELECT 
            T.TempPurchaseId,
            ROW_NUMBER() OVER (
                PARTITION BY T.EmpId, T.PayeeId, T.PurchaseId
                ORDER BY T.LineId, T.TempPurchaseId     -- choose your order
            ) AS NewLineId
        FROM TempPurchase T
        JOIN Changed C
          ON  C.EmpId      = T.EmpId
          AND C.PayeeId   = T.PayeeId
          AND C.PurchaseId= T.PurchaseId
    )
    UPDATE T
    SET T.LineId = R.NewLineId
    FROM TempPurchase T
    JOIN Renumber R
      ON T.TempPurchaseId = R.TempPurchaseId;
END;
