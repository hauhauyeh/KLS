SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ASB_ASSIGNBILLS_20260711: batch-assign many bills to ONE shipment (shipment-centric).
-- Mirrors the proven Shipment_Assign side effects (insert link -> Shipment_Allocation ->
-- Shipment_AllocationInventoryClear per bill -> Shipment_GenerateBill once), but is
-- DELIBERATELY STRICTER than the single-assign template: the whole batch is wrapped in one
-- transaction with XACT_ABORT ON + TRY/CATCH so a mid-batch failure cannot leave some bills
-- assigned/allocated and others not (do NOT "simplify" this back to an unwrapped body).
CREATE OR ALTER PROCEDURE [dbo].[Shipment_AssignBills]   -- EXEC dbo.Shipment_AssignBills @ShipmentId=55, @PurchaseIds='12345,12346'
    @ShipmentId  INT,
    @PurchaseIds NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Parse the id list up front. Keep only NON-EMPTY tokens (trailing/duplicate commas are
    -- ignored), but a non-empty token that is not a valid integer is a HARD reject - this SP is
    -- the write boundary, so "all selected bills validated" must be strictly true.
    DECLARE @Tokens TABLE (RawTok NVARCHAR(50), ParsedId INT NULL);
    INSERT INTO @Tokens (RawTok, ParsedId)
    SELECT NULLIF(LTRIM(RTRIM(value)), ''),
           TRY_CAST(NULLIF(LTRIM(RTRIM(value)), '') AS INT)
    FROM STRING_SPLIT(ISNULL(@PurchaseIds, ''), ',')
    WHERE NULLIF(LTRIM(RTRIM(value)), '') IS NOT NULL;

    IF EXISTS (SELECT 1 FROM @Tokens WHERE ParsedId IS NULL)
        THROW 50066, 'One or more selected bill ids are not valid integers.', 1;

    DECLARE @Ids TABLE (PurchaseId INT PRIMARY KEY);
    INSERT INTO @Ids (PurchaseId) SELECT DISTINCT ParsedId FROM @Tokens;

    ------------------------------------------------------------
    -- Validate BEFORE any mutation (fail fast)
    ------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM dbo.Shipment WHERE ShipmentId = @ShipmentId)
        THROW 50061, 'Shipment not found.', 1;

    IF NOT EXISTS (SELECT 1 FROM @Ids)
        THROW 50062, 'No valid bills were selected.', 1;

    -- The generated consolidated shipment bill must not be locked or paid.
    IF EXISTS (
        SELECT 1 FROM dbo.Purchase p
        WHERE p.IsShipment = 1
          AND p.SourceShipmentId = @ShipmentId
          AND (p.IsLocked = 1 OR ISNULL(p.PaymentApplied, 0) > 0)
    )
        THROW 50063, 'Shipment bill is locked or partially paid. Cannot add bills.', 1;

    -- Every selected purchase must exist, be bill stage (StageId = 6) and not a shipment bill.
    IF EXISTS (
        SELECT 1 FROM @Ids i
        LEFT JOIN dbo.Purchase p ON p.PurchaseId = i.PurchaseId
        WHERE p.PurchaseId IS NULL
           OR p.StageId <> 6
           OR ISNULL(p.IsShipment, 0) = 1
    )
        THROW 50064, 'One or more selected bills are invalid (not found, not bill stage, or is a shipment bill).', 1;

    -- Locked/paid SOURCE bills are financially final - assignment would push new shipment
    -- landed-cost changes onto them (via Shipment_Allocation/InventoryClear). UI gating alone
    -- is not enough; block at the write so a stale/API path cannot assign them either.
    IF EXISTS (
        SELECT 1 FROM @Ids i
        JOIN dbo.Purchase p ON p.PurchaseId = i.PurchaseId
        WHERE ISNULL(p.IsLocked, 0) = 1 OR ISNULL(p.PaymentApplied, 0) > 0
    )
        THROW 50068, 'One or more selected bills are locked or paid and cannot be assigned to a shipment.', 1;

    -- One-purchase-one-shipment: none may already be assigned to any shipment.
    IF EXISTS (
        SELECT 1 FROM @Ids i
        JOIN dbo.ShipmentPurchase sp ON sp.PurchaseId = i.PurchaseId
    )
        THROW 50065, 'One or more selected bills are already assigned to a shipment. Unassign them first.', 1;

    ------------------------------------------------------------
    -- Mutate atomically
    ------------------------------------------------------------
    BEGIN TRY
        BEGIN TRAN;

            -- 1) Insert all links; fail fast if the insert did not take every row
            INSERT INTO dbo.ShipmentPurchase (ShipmentId, PurchaseId)
            SELECT @ShipmentId, i.PurchaseId FROM @Ids i;

            IF @@ROWCOUNT <> (SELECT COUNT(*) FROM @Ids)
                THROW 50067, 'Assignment insert count did not match the selected bills.', 1;

            -- 2) Allocate + inventory-clear per assigned bill (same as Shipment_Assign)
            DECLARE @Pid INT;
            DECLARE bill_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT PurchaseId FROM @Ids;
            OPEN bill_cursor;
            FETCH NEXT FROM bill_cursor INTO @Pid;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                EXEC dbo.Shipment_Allocation @PurchaseId = @Pid, @AllocationType = NULL;
                EXEC dbo.Shipment_AllocationInventoryClear @Pid;
                FETCH NEXT FROM bill_cursor INTO @Pid;
            END
            CLOSE bill_cursor;
            DEALLOCATE bill_cursor;

            -- 3) Generate/regenerate the consolidated shipment bill ONCE at the end
            EXEC dbo.Shipment_GenerateBill @ShipmentId;

        COMMIT;
    END TRY
    BEGIN CATCH
        -- Clean up the cursor if it was left open/allocated, roll back, then re-raise.
        IF CURSOR_STATUS('local', 'bill_cursor') >= -1
        BEGIN
            IF CURSOR_STATUS('local', 'bill_cursor') > -1
                CLOSE bill_cursor;
            DEALLOCATE bill_cursor;
        END

        IF @@TRANCOUNT > 0
            ROLLBACK;

        THROW;
    END CATCH

    -- Minimal result: how many were assigned
    SELECT AssignedCount = (SELECT COUNT(*) FROM @Ids);
END
