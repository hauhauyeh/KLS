-- Add UsedMethod from ShipmentAllocation to Purchase_AssignedShipment
IF OBJECT_ID('dbo.Purchase_AssignedShipment_prev') IS NULL
    EXEC sp_rename 'Purchase_AssignedShipment', 'Purchase_AssignedShipment_prev';
GO

CREATE PROCEDURE [dbo].[Purchase_AssignedShipment]
    @PurchaseId INT,
    @IsShipment BIT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ROW_NUMBER() OVER(ORDER BY sp.ShipmentPurchaseId) AS Id,
        sp.ShipmentPurchaseId,
        sp.ShipmentId,
        s.ShipmentType,
        s.ContainerType,
        s.ContainerNo,
        s.Status,
        p.PayeeName,
        sc.ChargeId,
        sc.ChargeType,
        sc.AllocationMethod,
        sc.ChargeAmount,
        sc.Notes,
        sa_agg.UsedMethod
    FROM dbo.ShipmentPurchase sp
    INNER JOIN dbo.Shipment s ON sp.ShipmentId = s.ShipmentId
    INNER JOIN dbo.Payee p ON s.PayeeId = p.PayeeId
    LEFT JOIN dbo.ShipmentCharge sc ON sc.ShipmentId = s.ShipmentId
    OUTER APPLY (
        SELECT TOP 1 sa.AllocationMethod AS UsedMethod
        FROM dbo.ShipmentAllocation sa
        WHERE sa.ChargeId = sc.ChargeId
    ) sa_agg
    WHERE sp.PurchaseId = @PurchaseId
END
GO
