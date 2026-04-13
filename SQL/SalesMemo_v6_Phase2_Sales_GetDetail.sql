SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[Sales_GetDetail]
    @SalesId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        s.SalesNumber,
        s.DocType,
        s.ParentSalesNumber,
        sd.SalesDetailId,
        sd.SalesId,
        sd.OrdQty,
        sd.ShipQty,
        sd.BillQty,
        sd.Unit,
        sd.UnitPrice,
        sd.Notes,
        COALESCE(i.ItemName, a.AccountName) AS ItemName
    FROM dbo.SalesDetail AS sd
    LEFT JOIN dbo.Item AS i
        ON i.ItemId = sd.ItemId
    LEFT JOIN dbo.Account AS a
        ON a.AccountId = sd.AccountId
    INNER JOIN dbo.Sales AS s
        ON s.SalesId = sd.SalesId
    WHERE sd.SalesId = @SalesId

    ORDER BY sd.SalesDetailId;
END

