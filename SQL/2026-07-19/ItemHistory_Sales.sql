SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[ItemHistory_Sales] -- EXEC [dbo].[ItemHistory_Sales] @ItemId=0,@PayeeId=0,@Filterby=NULL,@ViewerSalesRepId=NULL
    @ItemId INT,
    @PayeeId INT,
    @Filterby NVARCHAR(50),
    @ViewerSalesRepId INT = NULL
AS
BEGIN
    -- SET NOCOUNT ON added to prevent extra result sets from
    -- interfering with SELECT statements.
    SET NOCOUNT ON;

    SELECT TOP 300
        sd.SalesDetailId,
        s.SalesNumber,
        s.SalesId,
        s.ShipDate,
        s.ShipId,
        p.PayeeName,
        sd.ShipQty,
        sd.Unit,
        sd.UnitPrice
    FROM Sales AS s
    INNER JOIN SalesDetail AS sd ON s.SalesId = sd.SalesId
    INNER JOIN Payee AS p ON p.PayeeId = s.ShipId
    INNER JOIN Customer AS c ON c.PayeeId = s.ShipId
    WHERE sd.ItemId = @ItemId
      AND (@PayeeId = 0 OR s.ShipId = @PayeeId)
      AND (@ViewerSalesRepId IS NULL OR c.SalesRepId = @ViewerSalesRepId)
      AND (
            @Filterby IS NULL
            OR (@Filterby = 'future' AND s.ShipDate > CONVERT(date, GETDATE()))
            OR (@Filterby = 'today' AND s.ShipDate = CONVERT(date, GETDATE()))
          )
    ORDER BY s.ShipDate DESC, p.PayeeName
END
GO
