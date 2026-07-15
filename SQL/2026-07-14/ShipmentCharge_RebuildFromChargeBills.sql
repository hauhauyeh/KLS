SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.ShipmentCharge_RebuildFromChargeBills -- EXEC dbo.ShipmentCharge_RebuildFromChargeBills @ShipmentId=61
    @ShipmentId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.ShipmentChargeBill WHERE ShipmentId = @ShipmentId)
        RETURN;

    BEGIN TRY
        BEGIN TRAN;

        -- Charge-bill mode owns source amounts. User-owned legacy lump rows must be
        -- converted first, otherwise generated summary rows would double the pool.
        IF EXISTS (
            SELECT 1
            FROM dbo.ShipmentCharge
            WHERE ShipmentId = @ShipmentId
              AND ShipmentPurchaseId IS NULL
              AND IsGeneratedFromChargeBills = 0
              AND ISNULL(ChargeAmount, 0) <> 0
        )
        BEGIN
            RAISERROR('ShipmentCharge_RebuildFromChargeBills: convert or remove user-owned legacy charges before rebuilding charge-bill summaries.', 16, 1);
        END

        -- If this shipment already has per-bill split rows for a type, the generated
        -- NULL-grain summary for that same type must not be created. First make sure
        -- the charge-bill lines agree with those per-bill rows, so stale source data
        -- fails loudly instead of hiding behind the skip.
        IF EXISTS (
            SELECT 1
            FROM (
                SELECT ChargeType, Amount = SUM(ISNULL(ChargeAmount, 0))
                FROM dbo.ShipmentCharge
                WHERE ShipmentId = @ShipmentId
                  AND ShipmentPurchaseId IS NOT NULL
                  AND ISNULL(ChargeAmount, 0) <> 0
                GROUP BY ChargeType
            ) p
            FULL JOIN (
                SELECT l.ChargeType, Amount = SUM(ISNULL(l.ChargeAmount, 0))
                FROM dbo.ShipmentChargeBill b
                JOIN dbo.ShipmentChargeBillLine l
                  ON l.ShipmentChargeBillId = b.ShipmentChargeBillId
                WHERE b.ShipmentId = @ShipmentId
                GROUP BY l.ChargeType
            ) b
              ON b.ChargeType = p.ChargeType
            WHERE ISNULL(p.Amount, 0) <> 0
              AND ABS(ISNULL(p.Amount, 0) - ISNULL(b.Amount, 0)) > 0.01
        )
        BEGIN
            RAISERROR('ShipmentCharge_RebuildFromChargeBills: charge-bill lines do not match existing per-bill split rows for this shipment.', 16, 1);
        END

        DELETE FROM dbo.ShipmentCharge
        WHERE ShipmentId = @ShipmentId
          AND ShipmentPurchaseId IS NULL
          AND IsGeneratedFromChargeBills = 1;

        INSERT INTO dbo.ShipmentCharge
        (
            ShipmentId,
            ShipmentPurchaseId,
            ChargeType,
            AllocationMethod,
            BillBasis,
            LineBasis,
            ChargeAmount,
            Notes,
            IsGeneratedFromChargeBills,
            UpdatedAt
        )
        SELECT
            @ShipmentId,
            NULL,
            l.ChargeType,
            CASE
                WHEN l.ChargeType = 'Freight'    THEN 'BY_VOLUME'
                WHEN l.ChargeType = 'CustomDuty' THEN 'BY_DUTY'
                WHEN l.ChargeType = 'Tariff'     THEN 'BY_TARIFF'
                ELSE 'BY_VALUE'
            END,
            NULL,
            NULL,
            SUM(l.ChargeAmount),
            'Generated from charge bills',
            1,
            GETUTCDATE()
        FROM dbo.ShipmentChargeBill b
        JOIN dbo.ShipmentChargeBillLine l
          ON l.ShipmentChargeBillId = b.ShipmentChargeBillId
        WHERE b.ShipmentId = @ShipmentId
          AND NOT EXISTS (
              SELECT 1
              FROM dbo.ShipmentCharge sc
              WHERE sc.ShipmentId = @ShipmentId
                AND sc.ChargeType = l.ChargeType
                AND sc.ShipmentPurchaseId IS NOT NULL
                AND ISNULL(sc.ChargeAmount, 0) <> 0
          )
        GROUP BY l.ChargeType
        HAVING SUM(l.ChargeAmount) > 0;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        ;THROW;
    END CATCH
END
GO
