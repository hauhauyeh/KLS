SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Report_Responsible] -- [Report_Responsible] '05/01/2026'
    @ShipDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @COGSAccountId INT;
    DECLARE @ISALEAccountId INT;

    SELECT @COGSAccountId = AccountId
    FROM Account
    WHERE AccountCode = '@COGS';

    SELECT @ISALEAccountId = AccountId
    FROM Account
    WHERE AccountCode = '@ISALE';

    CREATE TABLE #rptres
    (
        AutoId INT IDENTITY(1,1),
        SalesNumber INT,
        SalesDocNumber NVARCHAR(50),
        SalesId INT,
        ShipRoute NVARCHAR(10),
        PayeeName NVARCHAR(255),
        Instruction NVARCHAR(255),
        ItemId INT,
        ItemName NVARCHAR(255),
        Notes NVARCHAR(255),
        ShipQty DECIMAL(18,4),
        BillQty DECIMAL(18,4),
        Unit NVARCHAR(50),
        ResType NVARCHAR(50)
    );

    INSERT INTO #rptres
    (
        SalesId, SalesNumber, SalesDocNumber, ShipRoute, PayeeName, Instruction,
        ItemId, ItemName, Notes,
        ShipQty, BillQty, Unit, ResType
    )
    SELECT
        s.SalesId,
        s.SalesNumber,
        s.SalesDocNumber,
        s.ShipRoute,
        p.PayeeName,
        s.Instruction,
        sd.ItemId,
        i.ItemName,
        sd.Notes,
        sd.ShipQty,
        sd.BillQty,
        sd.Unit,
        CASE
            WHEN sd.BillQty = 0 AND sd.ShipQty = 0 THEN 'Out'
            WHEN sd.BillQty = 0 AND sd.ShipQty <> 0 THEN 'Free'
            WHEN sd.ShipQty < 0 THEN 'Return'
            WHEN sd.ShipQty = 0 AND sd.BillQty <> 0 THEN 'Charge'
        END AS ResType
    FROM Sales s
    INNER JOIN SalesDetail sd ON s.SalesId = sd.SalesId
    INNER JOIN Item i ON i.ItemId = sd.ItemId
    LEFT JOIN Payee p ON p.PayeeId = s.ShipId
    WHERE s.ShipDate = @ShipDate
      AND (
            (sd.BillQty = 0 AND sd.ShipQty = 0)
         OR (sd.BillQty = 0 AND sd.ShipQty <> 0)
         OR (sd.ShipQty < 0)
         OR (sd.ShipQty = 0 AND sd.BillQty <> 0)
      );

    ;WITH CTE_Journal AS
    (
        SELECT
            td.SourceDetailId,
            SUM(CASE WHEN td.AccountId = @ISALEAccountId THEN td.Amount ELSE 0 END) AS SalesPrice,
            SUM(CASE WHEN td.AccountId = @COGSAccountId THEN td.Amount ELSE 0 END) AS CostPrice
        FROM TransactionJournal t
        INNER JOIN TransactionJournalDetail td ON t.TxId = td.TxId
        WHERE t.TxDate = @ShipDate
          AND t.SourceDocType = 'Sales'
          AND td.AccountId IN (@ISALEAccountId, @COGSAccountId)
        GROUP BY td.SourceDetailId
    )
    INSERT INTO #rptres
    (
        SalesId, SalesNumber, SalesDocNumber, ShipRoute, PayeeName, Instruction,
        ItemId, ItemName, Notes,
        ShipQty, BillQty, Unit, ResType
    )
    SELECT
        sd.SalesId,
        s.SalesNumber,
        s.SalesDocNumber,
        s.ShipRoute,
        p.PayeeName,
        s.Instruction,
        sd.ItemId,
        i.ItemName,
        ISNULL(sd.Notes, '')
            + ' '
            + CONVERT(VARCHAR(50), c.CostPrice)
            + ' -> '
            + CONVERT(VARCHAR(50), c.SalesPrice) AS Notes,
        sd.ShipQty,
        sd.BillQty,
        sd.Unit,
        CASE
            WHEN c.CostPrice >= c.SalesPrice
                 AND c.SalesPrice > 0
                THEN 'Loss'

            WHEN c.SalesPrice > 0
                 AND m.MarginRatio > 1
                THEN 'Gain'
        END AS ResType
    FROM CTE_Journal c
    INNER JOIN SalesDetail sd ON c.SourceDetailId = sd.SalesDetailId
    INNER JOIN Sales s ON s.SalesId = sd.SalesId
    INNER JOIN Item i ON i.ItemId = sd.ItemId
    LEFT JOIN Payee p ON p.PayeeId = s.ShipId
    CROSS APPLY
    (
        SELECT MarginRatio =
            (c.SalesPrice - c.CostPrice) / NULLIF(c.SalesPrice, 0)
    ) m
    WHERE
        (
            c.CostPrice >= c.SalesPrice
            AND c.SalesPrice > 0
        )
        OR
        (
            c.SalesPrice > 0
            AND m.MarginRatio > 1
        );

    ;WITH cteadj AS
    (
        SELECT
            ia.AdjNumber,
            ia.AdjType,
            id.ItemId,
            i.ItemName,
            id.NewQty,
            id.Notes
        FROM InventoryAdj ia
        INNER JOIN InventoryAdjDetail id ON ia.AdjId = id.AdjId
        INNER JOIN Item i ON i.ItemId = id.ItemId
        WHERE ia.AdjDate = @ShipDate
    )
    INSERT INTO #rptres
    (
        Instruction, ItemId, ItemName, Notes,
        ShipQty, BillQty, ResType
    )
    SELECT
        AdjType,
        ItemId,
        ItemName,
        Notes,
        NULL,
        NewQty,
        'Adjustment'
    FROM cteadj;

    SELECT *
    FROM #rptres
    ORDER BY AutoId;

    DROP TABLE #rptres;
END
GO
