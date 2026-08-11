SET NOCOUNT ON;
SET XACT_ABORT ON;

/*
    Shipment_RepairClosedToAllocated

    Purpose:
      Shipment Status = 'Closed' is deprecated. Convert existing Closed shipments
      back to Allocated. Delete protection now comes from generated shipment AP
      bill paid/locked state in dbo.Shipment_Delete, not from Shipment.Status.

    Usage:
      1. Run with @ApplyRepair = 0 to preview only.
      2. Review the Preview rows and PreviewCount.
      3. Change @ApplyRepair to 1 and run once to repair.
*/

DECLARE @ApplyRepair bit = 0;

SELECT
    s.ShipmentId,
    s.Status,
    s.ContainerNo,
    s.PayeeId,
    s.UpdatedAt
FROM dbo.Shipment s
WHERE s.Status = 'Closed'
ORDER BY s.ShipmentId;

SELECT PreviewCount = COUNT(*)
FROM dbo.Shipment s
WHERE s.Status = 'Closed';

IF @ApplyRepair = 0
BEGIN
    PRINT 'Preview only. Set @ApplyRepair = 1 to update Closed shipments to Allocated.';
    RETURN;
END;

BEGIN TRAN;

UPDATE s
SET Status = 'Allocated',
    UpdatedAt = GETUTCDATE()
OUTPUT
    inserted.ShipmentId,
    deleted.Status AS OldStatus,
    inserted.Status AS NewStatus,
    inserted.ContainerNo,
    inserted.UpdatedAt
FROM dbo.Shipment s
WHERE s.Status = 'Closed';

DECLARE @Rows int = @@ROWCOUNT;

COMMIT TRAN;

SELECT RepairRows = @Rows;

SELECT RemainingClosedCount = COUNT(*)
FROM dbo.Shipment s
WHERE s.Status = 'Closed';
