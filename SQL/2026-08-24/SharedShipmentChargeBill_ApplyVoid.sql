SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.SharedShipmentChargeBill_Apply -- EXEC dbo.SharedShipmentChargeBill_Apply @SharedShipmentChargeBillId = 1
    @SharedShipmentChargeBillId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @OwnTran BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE
        @VendorPayeeId INT,
        @BillDate DATE,
        @Status NVARCHAR(20),
        @ChargeType NVARCHAR(50),
        @SourceAmount DECIMAL(18,2),
        @LineCount INT,
        @SplitCount INT,
        @GeneratedChildCount INT;

    DECLARE @AffectedShipments TABLE (ShipmentId INT PRIMARY KEY);

    BEGIN TRY
        IF @OwnTran = 1
            BEGIN TRAN;

        SELECT
            @VendorPayeeId = b.VendorPayeeId,
            @BillDate = b.BillDate,
            @Status = b.Status
        FROM dbo.SharedShipmentChargeBill b WITH (UPDLOCK, HOLDLOCK)
        WHERE b.SharedShipmentChargeBillId = @SharedShipmentChargeBillId;

        IF @VendorPayeeId IS NULL
            THROW 50301, 'SharedShipmentChargeBill_Apply: shared charge bill not found.', 1;

        IF @Status = N'Applied'
        BEGIN
            SELECT
                @GeneratedChildCount = COUNT(*)
            FROM dbo.ShipmentChargeBill scb
            JOIN dbo.SharedShipmentChargeBillSplit s
              ON s.SharedShipmentChargeBillSplitId = scb.SourceSharedShipmentChargeBillSplitId
            WHERE s.SharedShipmentChargeBillId = @SharedShipmentChargeBillId;

            SELECT @SplitCount = COUNT(*)
            FROM dbo.SharedShipmentChargeBillSplit
            WHERE SharedShipmentChargeBillId = @SharedShipmentChargeBillId;

            IF @GeneratedChildCount <> @SplitCount OR @SplitCount = 0
                THROW 50302, 'SharedShipmentChargeBill_Apply: applied shared bill has inconsistent generated children.', 1;

            IF @OwnTran = 1
                COMMIT TRAN;

            SELECT
                @SharedShipmentChargeBillId AS SharedShipmentChargeBillId,
                N'Applied' AS Status,
                @GeneratedChildCount AS GeneratedChildCount,
                @SplitCount AS AffectedShipmentCount,
                N'Shared charge bill is already applied.' AS Message;
            RETURN;
        END

        IF @Status <> N'Draft'
            THROW 50303, 'SharedShipmentChargeBill_Apply: only Draft shared charge bills can be applied.', 1;

        SELECT
            @LineCount = COUNT(*),
            @ChargeType = MAX(l.ChargeType),
            @SourceAmount = CAST(SUM(l.ChargeAmount) AS DECIMAL(18,2))
        FROM dbo.SharedShipmentChargeBillLine l
        WHERE l.SharedShipmentChargeBillId = @SharedShipmentChargeBillId;

        IF @LineCount <> 1
            THROW 50304, 'SharedShipmentChargeBill_Apply: exactly one source line is required.', 1;

        IF @SourceAmount <= 0
            THROW 50305, 'SharedShipmentChargeBill_Apply: source amount must be positive.', 1;

        UPDATE dbo.SharedShipmentChargeBillSplit
        SET GeneratedVendorDocNumber = NULLIF(LTRIM(RTRIM(GeneratedVendorDocNumber)), N''),
            UpdatedAt = GETUTCDATE()
        WHERE SharedShipmentChargeBillId = @SharedShipmentChargeBillId;

        SELECT @SplitCount = COUNT(*)
        FROM dbo.SharedShipmentChargeBillSplit
        WHERE SharedShipmentChargeBillId = @SharedShipmentChargeBillId;

        IF @SplitCount = 0
            THROW 50306, 'SharedShipmentChargeBill_Apply: at least one shipment split is required.', 1;

        IF EXISTS (
            SELECT 1
            FROM dbo.SharedShipmentChargeBillSplit s
            WHERE s.SharedShipmentChargeBillId = @SharedShipmentChargeBillId
              AND s.SplitAmount <= 0
        )
            THROW 50307, 'SharedShipmentChargeBill_Apply: every split amount must be positive.', 1;

        IF EXISTS (
            SELECT 1
            FROM dbo.SharedShipmentChargeBillSplit s
            WHERE s.SharedShipmentChargeBillId = @SharedShipmentChargeBillId
              AND s.GeneratedVendorDocNumber IS NULL
        )
            THROW 50308, 'SharedShipmentChargeBill_Apply: generated vendor document number is required for every split.', 1;

        IF EXISTS (
            SELECT 1
            FROM dbo.SharedShipmentChargeBillSplit s
            WHERE s.SharedShipmentChargeBillId = @SharedShipmentChargeBillId
              AND LEN(s.GeneratedVendorDocNumber) > 100
        )
            THROW 50309, 'SharedShipmentChargeBill_Apply: generated vendor document number cannot exceed 100 characters.', 1;

        IF (
            SELECT COUNT(DISTINCT s.SplitMethod)
            FROM dbo.SharedShipmentChargeBillSplit s
            WHERE s.SharedShipmentChargeBillId = @SharedShipmentChargeBillId
        ) <> 1
            THROW 50310, 'SharedShipmentChargeBill_Apply: all splits must use the same split method.', 1;

        IF EXISTS (
            SELECT 1
            FROM dbo.SharedShipmentChargeBillSplit s
            WHERE s.SharedShipmentChargeBillId = @SharedShipmentChargeBillId
              AND s.SplitMethod = N'Percentage'
              AND s.SplitPercent IS NULL
        )
            THROW 50311, 'SharedShipmentChargeBill_Apply: percentage splits require split percent.', 1;

        IF EXISTS (
            SELECT 1
            FROM dbo.SharedShipmentChargeBillSplit s
            WHERE s.SharedShipmentChargeBillId = @SharedShipmentChargeBillId
              AND s.SplitMethod = N'Percentage'
            HAVING CAST(SUM(s.SplitPercent) AS DECIMAL(18,6)) <> 100.000000
        )
            THROW 50312, 'SharedShipmentChargeBill_Apply: percentage splits must total 100.000000.', 1;

        IF (
            SELECT CAST(SUM(s.SplitAmount) AS DECIMAL(18,2))
            FROM dbo.SharedShipmentChargeBillSplit s
            WHERE s.SharedShipmentChargeBillId = @SharedShipmentChargeBillId
        ) <> @SourceAmount
            THROW 50313, 'SharedShipmentChargeBill_Apply: split total must match source amount.', 1;

        IF EXISTS (
            SELECT s.GeneratedVendorDocNumber
            FROM dbo.SharedShipmentChargeBillSplit s
            WHERE s.SharedShipmentChargeBillId = @SharedShipmentChargeBillId
            GROUP BY s.GeneratedVendorDocNumber
            HAVING COUNT(*) > 1
        )
            THROW 50314, 'SharedShipmentChargeBill_Apply: generated vendor document numbers must be unique on this shared bill.', 1;

        IF EXISTS (
            SELECT 1
            FROM dbo.SharedShipmentChargeBillSplit s
            LEFT JOIN dbo.Shipment sh
              ON sh.ShipmentId = s.ShipmentId
            WHERE s.SharedShipmentChargeBillId = @SharedShipmentChargeBillId
              AND sh.ShipmentId IS NULL
        )
            THROW 50315, 'SharedShipmentChargeBill_Apply: target shipment not found.', 1;

        IF EXISTS (
            SELECT 1
            FROM dbo.SharedShipmentChargeBillSplit s
            JOIN dbo.Shipment sh
              ON sh.ShipmentId = s.ShipmentId
            WHERE s.SharedShipmentChargeBillId = @SharedShipmentChargeBillId
              AND sh.Status = 'Closed'
        )
            THROW 50316, 'SharedShipmentChargeBill_Apply: closed shipments cannot receive shared charge bills.', 1;

        IF EXISTS (
            SELECT 1
            FROM dbo.SharedShipmentChargeBillSplit s
            JOIN dbo.Purchase p
              ON p.PayeeId = @VendorPayeeId
             AND p.VendorDocNumber = s.GeneratedVendorDocNumber
            WHERE s.SharedShipmentChargeBillId = @SharedShipmentChargeBillId
        )
            THROW 50317, 'SharedShipmentChargeBill_Apply: Vendor DocNum already exists for this vendor.', 1;

        IF EXISTS (
            SELECT 1
            FROM dbo.SharedShipmentChargeBillSplit s
            JOIN dbo.ShipmentChargeBill scb
              ON scb.SourceSharedShipmentChargeBillSplitId = s.SharedShipmentChargeBillSplitId
            WHERE s.SharedShipmentChargeBillId = @SharedShipmentChargeBillId
        )
            THROW 50318, 'SharedShipmentChargeBill_Apply: generated child charge bills already exist.', 1;

        INSERT INTO @AffectedShipments (ShipmentId)
        SELECT DISTINCT s.ShipmentId
        FROM dbo.SharedShipmentChargeBillSplit s
        WHERE s.SharedShipmentChargeBillId = @SharedShipmentChargeBillId;

        -- Apply creates ordinary charge-bill artifacts only. Final AP purchase creation remains behind Confirm Charges Complete.
        INSERT INTO dbo.ShipmentChargeBill
        (
            ShipmentId,
            VendorPayeeId,
            VendorDocNumber,
            BillDate,
            PurchaseId,
            Notes,
            SourceSharedShipmentChargeBillSplitId,
            CreatedAt
        )
        SELECT
            s.ShipmentId,
            @VendorPayeeId,
            s.GeneratedVendorDocNumber,
            @BillDate,
            NULL,
            s.Notes,
            s.SharedShipmentChargeBillSplitId,
            GETUTCDATE()
        FROM dbo.SharedShipmentChargeBillSplit s
        WHERE s.SharedShipmentChargeBillId = @SharedShipmentChargeBillId
        ORDER BY s.SharedShipmentChargeBillSplitId;

        INSERT INTO dbo.ShipmentChargeBillLine
        (
            ShipmentChargeBillId,
            ChargeType,
            ChargeAmount,
            Notes,
            CreatedAt
        )
        SELECT
            scb.ShipmentChargeBillId,
            @ChargeType,
            s.SplitAmount,
            l.Notes,
            GETUTCDATE()
        FROM dbo.SharedShipmentChargeBillSplit s
        JOIN dbo.ShipmentChargeBill scb
          ON scb.SourceSharedShipmentChargeBillSplitId = s.SharedShipmentChargeBillSplitId
        JOIN dbo.SharedShipmentChargeBillLine l
          ON l.SharedShipmentChargeBillId = s.SharedShipmentChargeBillId
        WHERE s.SharedShipmentChargeBillId = @SharedShipmentChargeBillId;

        DECLARE @ShipmentId INT;
        DECLARE shipment_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT ShipmentId FROM @AffectedShipments;

        OPEN shipment_cursor;
        FETCH NEXT FROM shipment_cursor INTO @ShipmentId;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC dbo.Shipment_ResetCompletionAndReallocate
                 @ShipmentId = @ShipmentId,
                 @RebuildChargeSummaries = 1,
                 @DeleteGeneratedApBills = 1;

            FETCH NEXT FROM shipment_cursor INTO @ShipmentId;
        END

        CLOSE shipment_cursor;
        DEALLOCATE shipment_cursor;

        UPDATE dbo.SharedShipmentChargeBill
        SET Status = N'Applied',
            UpdatedAt = GETUTCDATE()
        WHERE SharedShipmentChargeBillId = @SharedShipmentChargeBillId;

        SELECT @GeneratedChildCount = COUNT(*)
        FROM dbo.ShipmentChargeBill scb
        JOIN dbo.SharedShipmentChargeBillSplit s
          ON s.SharedShipmentChargeBillSplitId = scb.SourceSharedShipmentChargeBillSplitId
        WHERE s.SharedShipmentChargeBillId = @SharedShipmentChargeBillId;

        IF @OwnTran = 1
            COMMIT TRAN;

        SELECT
            @SharedShipmentChargeBillId AS SharedShipmentChargeBillId,
            N'Applied' AS Status,
            @GeneratedChildCount AS GeneratedChildCount,
            @SplitCount AS AffectedShipmentCount,
            N'Shared charge bill applied.' AS Message;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'shipment_cursor') >= 0 CLOSE shipment_cursor;
        IF CURSOR_STATUS('local', 'shipment_cursor') >= -1 DEALLOCATE shipment_cursor;
        IF @OwnTran = 1 AND @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.SharedShipmentChargeBill_Void -- EXEC dbo.SharedShipmentChargeBill_Void @SharedShipmentChargeBillId = 1
    @SharedShipmentChargeBillId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @OwnTran BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE
        @Status NVARCHAR(20),
        @GeneratedChildCount INT,
        @AffectedShipmentCount INT;

    DECLARE @AffectedShipments TABLE (ShipmentId INT PRIMARY KEY);

    BEGIN TRY
        IF @OwnTran = 1
            BEGIN TRAN;

        SELECT @Status = b.Status
        FROM dbo.SharedShipmentChargeBill b WITH (UPDLOCK, HOLDLOCK)
        WHERE b.SharedShipmentChargeBillId = @SharedShipmentChargeBillId;

        IF @Status IS NULL
            THROW 50401, 'SharedShipmentChargeBill_Void: shared charge bill not found.', 1;

        IF @Status = N'Void'
        BEGIN
            SELECT
                @GeneratedChildCount = COUNT(*),
                @AffectedShipmentCount = COUNT(DISTINCT scb.ShipmentId)
            FROM dbo.ShipmentChargeBill scb
            JOIN dbo.SharedShipmentChargeBillSplit s
              ON s.SharedShipmentChargeBillSplitId = scb.SourceSharedShipmentChargeBillSplitId
            WHERE s.SharedShipmentChargeBillId = @SharedShipmentChargeBillId;

            IF @GeneratedChildCount <> 0
                THROW 50402, 'SharedShipmentChargeBill_Void: void shared bill still has generated child charge bills.', 1;

            IF @OwnTran = 1
                COMMIT TRAN;

            SELECT
                @SharedShipmentChargeBillId AS SharedShipmentChargeBillId,
                N'Void' AS Status,
                0 AS RemovedChildCount,
                0 AS AffectedShipmentCount,
                N'Shared charge bill is already void.' AS Message;
            RETURN;
        END

        IF @Status <> N'Applied'
            THROW 50403, 'SharedShipmentChargeBill_Void: only Applied shared charge bills can be voided.', 1;

        INSERT INTO @AffectedShipments (ShipmentId)
        SELECT DISTINCT scb.ShipmentId
        FROM dbo.ShipmentChargeBill scb
        JOIN dbo.SharedShipmentChargeBillSplit s
          ON s.SharedShipmentChargeBillSplitId = scb.SourceSharedShipmentChargeBillSplitId
        WHERE s.SharedShipmentChargeBillId = @SharedShipmentChargeBillId;

        SELECT @GeneratedChildCount = COUNT(*)
        FROM dbo.ShipmentChargeBill scb
        JOIN dbo.SharedShipmentChargeBillSplit s
          ON s.SharedShipmentChargeBillSplitId = scb.SourceSharedShipmentChargeBillSplitId
        WHERE s.SharedShipmentChargeBillId = @SharedShipmentChargeBillId;

        IF @GeneratedChildCount = 0
            THROW 50404, 'SharedShipmentChargeBill_Void: no generated child charge bills found.', 1;

        IF EXISTS (
            SELECT 1
            FROM dbo.ShipmentChargeBill scb
            JOIN dbo.SharedShipmentChargeBillSplit s
              ON s.SharedShipmentChargeBillSplitId = scb.SourceSharedShipmentChargeBillSplitId
            JOIN dbo.Purchase p
              ON p.PurchaseId = scb.PurchaseId
            WHERE s.SharedShipmentChargeBillId = @SharedShipmentChargeBillId
              AND (ISNULL(p.IsLocked, 0) = 1 OR ISNULL(p.PaymentApplied, 0) > 0)
        )
            THROW 50405, 'SharedShipmentChargeBill_Void: generated AP bill is locked or paid.', 1;

        DECLARE @ShipmentId INT;
        DECLARE shipment_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT ShipmentId FROM @AffectedShipments;

        OPEN shipment_cursor;
        FETCH NEXT FROM shipment_cursor INTO @ShipmentId;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC dbo.Shipment_ResetCompletionAndReallocate
                 @ShipmentId = @ShipmentId,
                 @RebuildChargeSummaries = 0,
                 @DeleteGeneratedApBills = 1;

            FETCH NEXT FROM shipment_cursor INTO @ShipmentId;
        END

        CLOSE shipment_cursor;
        DEALLOCATE shipment_cursor;

        DELETE scbl
        FROM dbo.ShipmentChargeBillLine scbl
        JOIN dbo.ShipmentChargeBill scb
          ON scb.ShipmentChargeBillId = scbl.ShipmentChargeBillId
        JOIN dbo.SharedShipmentChargeBillSplit s
          ON s.SharedShipmentChargeBillSplitId = scb.SourceSharedShipmentChargeBillSplitId
        WHERE s.SharedShipmentChargeBillId = @SharedShipmentChargeBillId;

        DELETE scb
        FROM dbo.ShipmentChargeBill scb
        JOIN dbo.SharedShipmentChargeBillSplit s
          ON s.SharedShipmentChargeBillSplitId = scb.SourceSharedShipmentChargeBillSplitId
        WHERE s.SharedShipmentChargeBillId = @SharedShipmentChargeBillId;

        DECLARE reallocate_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT ShipmentId FROM @AffectedShipments;

        OPEN reallocate_cursor;
        FETCH NEXT FROM reallocate_cursor INTO @ShipmentId;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC dbo.Shipment_ResetCompletionAndReallocate
                 @ShipmentId = @ShipmentId,
                 @RebuildChargeSummaries = 1,
                 @DeleteGeneratedApBills = 0;

            FETCH NEXT FROM reallocate_cursor INTO @ShipmentId;
        END

        CLOSE reallocate_cursor;
        DEALLOCATE reallocate_cursor;

        UPDATE dbo.SharedShipmentChargeBill
        SET Status = N'Void',
            UpdatedAt = GETUTCDATE()
        WHERE SharedShipmentChargeBillId = @SharedShipmentChargeBillId;

        SELECT @AffectedShipmentCount = COUNT(*) FROM @AffectedShipments;

        IF @OwnTran = 1
            COMMIT TRAN;

        SELECT
            @SharedShipmentChargeBillId AS SharedShipmentChargeBillId,
            N'Void' AS Status,
            @GeneratedChildCount AS RemovedChildCount,
            @AffectedShipmentCount AS AffectedShipmentCount,
            N'Shared charge bill voided.' AS Message;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'shipment_cursor') >= 0 CLOSE shipment_cursor;
        IF CURSOR_STATUS('local', 'shipment_cursor') >= -1 DEALLOCATE shipment_cursor;
        IF CURSOR_STATUS('local', 'reallocate_cursor') >= 0 CLOSE reallocate_cursor;
        IF CURSOR_STATUS('local', 'reallocate_cursor') >= -1 DEALLOCATE reallocate_cursor;
        IF @OwnTran = 1 AND @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO
