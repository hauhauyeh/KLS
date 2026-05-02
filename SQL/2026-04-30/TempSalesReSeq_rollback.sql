-- Baseline dumped from live DB: 2026-04-16
-- Rollback: restores TRG_Update_TempSalesReSeq to pre-feature state

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
    -- 1. Find all (EmpId, PayeeId, PurchaseId) affected by this change
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
    -- 2. For those groups, recompute LineId = 1,2,3,... 
    Renumber AS
    (
        SELECT 
            T.TempSalesId,
            ROW_NUMBER() OVER (
                PARTITION BY T.EmpId, T.PayeeId, T.SalesId
                ORDER BY T.LineId, T.TempSalesId     -- choose your order
            ) AS NewLineId
        FROM TempSales T
        JOIN Changed C
          ON  C.EmpId   = T.EmpId
          AND C.PayeeId = T.PayeeId
          AND C.SalesId = T.SalesId
    )
    UPDATE T
    SET T.LineId = R.NewLineId
    FROM TempSales T
    JOIN Renumber R
      ON T.TempSalesId = R.TempSalesId;
END;
