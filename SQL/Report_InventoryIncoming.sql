CREATE PROCEDURE [dbo].[Report_InventoryIncoming]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ROW_NUMBER() OVER (ORDER BY pd.ItemId, p.ArrivalDate) AS AutoId,
        pd.ItemId,
        p.PurchaseNumber,
        py.PayeeName AS VendorName,
        (pd.OrdQty0 - ISNULL(pd.BaseReceiveQty, 0)) AS IncomingQty,
        pd.Unit,
        p.ArrivalDate
    FROM PurchaseDetail pd
    INNER JOIN Purchase p ON p.PurchaseId = pd.PurchaseId
    LEFT JOIN Payee py ON py.PayeeId = p.PayeeId
    WHERE p.StageId IN (1, 2, 3, 4)
      AND pd.ItemId IS NOT NULL
      AND (pd.OrdQty0 - ISNULL(pd.BaseReceiveQty, 0)) > 0
    ORDER BY pd.ItemId, p.ArrivalDate;
END
GO
