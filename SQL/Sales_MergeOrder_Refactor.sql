SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.Sales_MergeOrder_prev', 'P') IS NOT NULL
    DROP PROCEDURE dbo.Sales_MergeOrder_prev;
GO

EXEC sp_rename 'dbo.Sales_MergeOrder', 'Sales_MergeOrder_prev';
GO

CREATE PROCEDURE [dbo].[Sales_MergeOrder]
    @SalesIds NVARCHAR(MAX),
    @Destination NVARCHAR(10),
    @EmpId INT
AS
BEGIN
    -- SET NOCOUNT ON added to prevent extra result sets from
    -- interfering with SELECT statements.
    SET NOCOUNT ON;

    DECLARE @SalesNumber INT;
    DECLARE @NewSalesId INT;
    DECLARE @PayeeId INT;

    DECLARE @StageId INT;
    DECLARE @SalesDate DATETIME;
    DECLARE @ShipDate DATE;
    DECLARE @ShipRoute NVARCHAR(50);
    DECLARE @RouteOrder INT;
    DECLARE @TermId INT;
    DECLARE @Instruction NVARCHAR(300);
    DECLARE @CustPONumber NVARCHAR(100);
    DECLARE @TruckNumber NVARCHAR(50);
    DECLARE @ShippingCarrierId INT;
    DECLARE @TrackingNo NVARCHAR(100);
    DECLARE @ExternalId NVARCHAR(50);
    DECLARE @IsLoadSeparate BIT;
    DECLARE @LoadOrder INT;
    DECLARE @LoadRoute NVARCHAR(10);
    DECLARE @IsLocked BIT;
    DECLARE @IsStatementAttached BIT;
    DECLARE @Deliverby INT;
    DECLARE @Enterby INT;
    DECLARE @Loadby INT;
    DECLARE @Updateby INT;
    DECLARE @InstructionCount INT;

    DECLARE @InstructionSource TABLE
    (
        SalesNumber INT PRIMARY KEY,
        InstructionText NVARCHAR(300)
    );

    CREATE TABLE #MergeOrder
    (
        Id INT IDENTITY(1,1),
        SalesId INT PRIMARY KEY
    );

    INSERT INTO #MergeOrder (SalesId)
    SELECT DISTINCT TRY_CAST(value AS INT)
    FROM STRING_SPLIT(@SalesIds, ',')
    WHERE TRY_CAST(value AS INT) IS NOT NULL;

    IF NOT EXISTS (SELECT 1 FROM #MergeOrder)
    BEGIN
        RAISERROR('Sales_MergeOrder requires at least one valid SalesId.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM #MergeOrder mo
        LEFT JOIN Sales s ON s.SalesId = mo.SalesId
        WHERE s.SalesId IS NULL
    )
    BEGIN
        RAISERROR('One or more sales orders were not found.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM Sales s
        INNER JOIN #MergeOrder m ON s.SalesId = m.SalesId
        GROUP BY s.ShipId
        HAVING COUNT(*) > 0
    )
    AND (
        SELECT COUNT(DISTINCT s.ShipId)
        FROM Sales s
        INNER JOIN #MergeOrder m ON s.SalesId = m.SalesId
    ) > 1
    BEGIN
        RAISERROR('Sales_MergeOrder only supports orders from the same customer.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM Sales s
        INNER JOIN #MergeOrder m ON s.SalesId = m.SalesId
        WHERE ISNULL(s.DocType, 'SO') <> 'SO'
           OR s.ParentSalesNumber IS NOT NULL
    )
    BEGIN
        RAISERROR('Sales_MergeOrder currently supports standard sales orders only.', 16, 1);
        RETURN;
    END;

    IF @Destination = 'New'
    BEGIN
        SELECT TOP (1)
            @SalesNumber = SalesNumber,
            @StageId = StageId,
            @SalesDate = SalesDate,
            @ShipDate = ShipDate,
            @ShipRoute = ShipRoute,
            @RouteOrder = RouteOrder,
            @PayeeId = ShipId,
            @TermId = TermId,
            @Instruction = Instruction,
            @CustPONumber = CustPONumber,
            @TruckNumber = TruckNumber,
            @ShippingCarrierId = ShippingCarrierId,
            @TrackingNo = TrackingNo,
            @ExternalId = ExternalId,
            @IsLoadSeparate = IsLoadSeparate,
            @LoadOrder = LoadOrder,
            @LoadRoute = LoadRoute,
            @IsLocked = IsLocked,
            @IsStatementAttached = IsStatementAttached,
            @Deliverby = Deliverby,
            @Enterby = Enterby,
            @Loadby = Loadby,
            @Updateby = Updateby
        FROM Sales s
        INNER JOIN #MergeOrder m ON s.SalesId = m.SalesId
        ORDER BY SalesNumber DESC;
    END
    ELSE IF @Destination = 'Old'
    BEGIN
        SELECT TOP (1)
            @SalesNumber = SalesNumber,
            @StageId = StageId,
            @SalesDate = SalesDate,
            @ShipDate = ShipDate,
            @ShipRoute = ShipRoute,
            @RouteOrder = RouteOrder,
            @PayeeId = ShipId,
            @TermId = TermId,
            @Instruction = Instruction,
            @CustPONumber = CustPONumber,
            @TruckNumber = TruckNumber,
            @ShippingCarrierId = ShippingCarrierId,
            @TrackingNo = TrackingNo,
            @ExternalId = ExternalId,
            @IsLoadSeparate = IsLoadSeparate,
            @LoadOrder = LoadOrder,
            @LoadRoute = LoadRoute,
            @IsLocked = IsLocked,
            @IsStatementAttached = IsStatementAttached,
            @Deliverby = Deliverby,
            @Enterby = Enterby,
            @Loadby = Loadby,
            @Updateby = Updateby
        FROM Sales s
        INNER JOIN #MergeOrder m ON s.SalesId = m.SalesId
        ORDER BY SalesNumber ASC;
    END
    ELSE
    BEGIN
        RAISERROR('Sales_MergeOrder destination must be New or Old.', 16, 1);
        RETURN;
    END;

    INSERT INTO @InstructionSource (SalesNumber, InstructionText)
    SELECT
        MIN(s.SalesNumber),
        LTRIM(RTRIM(s.Instruction))
    FROM Sales s
    INNER JOIN #MergeOrder m ON s.SalesId = m.SalesId
    WHERE NULLIF(LTRIM(RTRIM(ISNULL(s.Instruction, ''))), '') IS NOT NULL
    GROUP BY LTRIM(RTRIM(s.Instruction));

    SELECT @InstructionCount = COUNT(*) FROM @InstructionSource;

    IF @InstructionCount = 1
    BEGIN
        SELECT TOP (1) @Instruction = InstructionText
        FROM @InstructionSource;
    END
    ELSE IF @InstructionCount > 1
    BEGIN
        SELECT @Instruction = LEFT(
            STUFF((
                SELECT CHAR(13) + CHAR(10) + '[SO ' + CAST(src.SalesNumber AS NVARCHAR(20)) + '] ' + src.InstructionText
                FROM @InstructionSource src
                ORDER BY src.SalesNumber
                FOR XML PATH(''), TYPE
            ).value('.', 'NVARCHAR(MAX)'), 1, 2, ''),
            300
        );
    END;

    DELETE FROM TempSales
    WHERE PayeeId = @PayeeId
      AND EmpId = @EmpId;

    INSERT INTO [TempSales]
    (
        [EmpId],
        [SalesId],
        [PayeeId],
        [LineType],
        [ItemId],
        [AccountId],
        [ItemUnitId],
        [Unit],
        [IsFree],
        [IsOut],
        [IsCRCG],
        [OrdQty],
        [ShipQty],
        [BillQty],
        [UnitPrice],
        [ExtTotal],
        [Notes],
        [IsTaxable],
        [OrgPrice],
        [DiscountPercent],
        [FactorToBase],
        [SalesDetailId],
        [ParentSalesNumber],
        [ParentTempSalesId],
        [RootTempSalesId],
        [CartLineType],
        [IsSystemManaged],
        [DisplaySort]
    )
    SELECT
        @EmpId,
        0,
        @PayeeId,
        sd.[LineType],
        sd.[ItemId],
        sd.[AccountId],
        sd.[ItemUnitId],
        sd.[Unit],
        CASE WHEN (sd.BillQty = 0 AND sd.ShipQty != 0) THEN 1 ELSE 0 END,
        CASE WHEN (sd.BillQty = 0 AND sd.ShipQty = 0) THEN 1 ELSE 0 END,
        CASE WHEN (sd.BillQty != 0 AND sd.ShipQty = 0) THEN 1 ELSE 0 END,
        sd.[OrdQty],
        sd.[ShipQty],
        sd.[BillQty],
        sd.[UnitPrice],
        sd.[ExtTotal],
        sd.[Notes],
        sd.[IsTaxable],
        sd.[OrgPrice],
        sd.[DiscountPercent],
        sd.[FactorToBase],
        sd.[SalesDetailId],
        NULL,
        NULL,
        NULL,
        ISNULL(sd.[CartLineType], 'MAIN'),
        ISNULL(sd.[IsSystemManaged], 0),
        sd.[DisplaySort]
    FROM Sales s
    INNER JOIN SalesDetail sd ON s.SalesId = sd.SalesId
    INNER JOIN #MergeOrder m ON s.SalesId = m.SalesId
    ORDER BY s.SalesNumber, sd.LineId;

    UPDATE ts
    SET ts.ParentTempSalesId = pts.TempSalesId,
        ts.RootTempSalesId = ISNULL(rts.TempSalesId, pts.TempSalesId)
    FROM TempSales ts
    INNER JOIN SalesDetail sd ON sd.SalesDetailId = ts.SalesDetailId
    LEFT JOIN TempSales pts
        ON pts.SalesDetailId = sd.ParentSalesDetailId
       AND pts.EmpId = @EmpId
       AND pts.SalesId = 0
       AND pts.PayeeId = @PayeeId
    LEFT JOIN TempSales rts
        ON rts.SalesDetailId = sd.RootSalesDetailId
       AND rts.EmpId = @EmpId
       AND rts.SalesId = 0
       AND rts.PayeeId = @PayeeId
    WHERE ts.EmpId = @EmpId
      AND ts.SalesId = 0
      AND ts.PayeeId = @PayeeId
      AND sd.ParentSalesDetailId IS NOT NULL;

    -- Refresh DisplaySort on PROMO_REWARD rows to match owner's current LineId
    UPDATE ts
    SET ts.DisplaySort = owner.LineId
    FROM TempSales ts
    INNER JOIN TempSales owner ON owner.TempSalesId = ts.ParentTempSalesId
    WHERE ts.CartLineType = 'PROMO_REWARD'
      AND ts.EmpId = @EmpId
      AND ts.SalesId = 0
      AND ts.PayeeId = @PayeeId;

    BEGIN TRY
        BEGIN TRAN;

        DELETE FROM Sales
        WHERE SalesId IN (SELECT SalesId FROM #MergeOrder);

        EXEC [Sales_Insert]
            @SalesId = @SalesNumber,
            @PayeeId = @PayeeId,
            @ShipDate = @ShipDate,
            @ShipRoute = @ShipRoute,
            @Instruction = @Instruction,
            @StageId = 0,
            @EmpId = @EmpId,
            @NewSalesId = @NewSalesId OUTPUT,
            @DocType = 'SO',
            @ParentSalesNumber = NULL,
            @AllowNoParentOverride = 0;

        UPDATE CustomerPaymentDetail
        SET SalesId = @NewSalesId
        WHERE SalesId IN (SELECT SalesId FROM #MergeOrder);

        UPDATE Sales
        SET
            StageId = @StageId,
            SalesDate = @SalesDate,
            ShipDate = @ShipDate,
            ShipRoute = @ShipRoute,
            RouteOrder = @RouteOrder,
            TermId = @TermId,
            Instruction = @Instruction,
            CustPONumber = @CustPONumber,
            TruckNumber = @TruckNumber,
            ShippingCarrierId = @ShippingCarrierId,
            TrackingNo = @TrackingNo,
            ExternalId = @ExternalId,
            IsLoadSeparate = @IsLoadSeparate,
            LoadOrder = @LoadOrder,
            LoadRoute = @LoadRoute,
            IsLocked = @IsLocked,
            IsStatementAttached = @IsStatementAttached,
            Deliverby = @Deliverby,
            Enterby = @Enterby,
            Loadby = @Loadby,
            Updateby = @Updateby,
            UpdatedAt = GETUTCDATE()
        WHERE SalesId = @NewSalesId;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;

        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrNum INT = ERROR_NUMBER();
        DECLARE @ErrLine INT = ERROR_LINE();

        -- Bubble up meaningful error
        RAISERROR('Sales_MergeOrder failed. %s (Err %d, Line %d)', 16, 1, @ErrMsg, @ErrNum, @ErrLine);
        RETURN;
    END CATCH
END
GO
