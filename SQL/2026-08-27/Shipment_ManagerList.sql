SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Shipment_ManagerList] -- EXEC dbo.Shipment_ManagerList @Pageno=1, @Pagesize=50, @Search=NULL, @StartDate=NULL, @EndDate=NULL, @PayeeId=NULL, @Filterby=NULL, @SortField=NULL, @SortOrder=NULL, @IsCount=0, @TotalCount=NULL
    @Pageno INT,
    @Pagesize INT,
    @Search NVARCHAR(50),
    @StartDate DATE,
    @EndDate DATE,
    @PayeeId INT,
    @Filterby NVARCHAR(100),
    @SortField NVARCHAR(50),
    @SortOrder NVARCHAR(50),
    @IsCount BIT,
    @TotalCount INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @S NVARCHAR(50) = NULLIF(LTRIM(RTRIM(@Search)), '');
    DECLARE @SearchNumber INT = TRY_CONVERT(INT, @S);
    DECLARE @Direction NVARCHAR(4) = CASE WHEN LOWER(ISNULL(@SortOrder, '')) = 'desc' THEN 'DESC' ELSE 'ASC' END;
    DECLARE @OrderBy NVARCHAR(300);

    SET @OrderBy =
        CASE @SortField
            WHEN 'ContainerSeq' THEN 'ContainerSeq'
            WHEN 'ShipmentId' THEN 'ShipmentIdSort'
            WHEN 'ContainerNo' THEN 'ContainerNo'
            WHEN 'PayeeName' THEN 'PayeeName'
            WHEN 'ETD' THEN 'ETD'
            WHEN 'ETA' THEN 'ETA'
            WHEN 'Status' THEN 'Status'
            WHEN 'DutyStatus' THEN 'DutyStatus'
            WHEN 'FactorPO' THEN 'FactorPO'
            WHEN 'VendorDocNumber' THEN 'VendorDocNumber'
            WHEN 'ShipperName' THEN 'ShipperName'
            WHEN 'CustomerName' THEN 'CustomerName'
            ELSE NULL
        END;

    IF @OrderBy IS NULL
        SET @OrderBy = 'SeqSortDate ASC, ShipmentIdSort ASC';
    ELSE IF @OrderBy = 'ShipmentIdSort'
        SET @OrderBy = @OrderBy + ' ' + @Direction;
    ELSE
        SET @OrderBy = @OrderBy + ' ' + @Direction + ', ShipmentIdSort ASC';

    DECLARE @Sql NVARCHAR(MAX) = N'
;WITH Base AS
(
    SELECT
        CAST(ROW_NUMBER() OVER (ORDER BY ISNULL(s.ETA, CONVERT(date, s.CreatedAt)), s.ShipmentId) AS int) AS ContainerSeq,
        s.ShipmentId,
        s.ShipmentId AS ShipmentIdSort,
        s.ShipmentType,
        s.ContainerNo,
        s.ContainerType,
        s.PayeeId,
        carrier.PayeeName,
        s.Origin,
        s.Destination,
        s.ETD,
        s.ETA,
        s.Status,
        s.DutyStatus,
        s.Notes,
        ISNULL(ch.TotalCharges, 0) AS TotalCharges,
        fpo.FactorPO,
        vdoc.VendorDocNumber,
        shipper.ShipperName,
        major.MajorItem,
        customer.CustomerName,
        s.AreChargesComplete,
        s.ChargesCompletedAt,
        s.ChargesCompletedBy,
        ISNULL(assigned.AssignedBillCount, 0) AS AssignedBillCount,
        ISNULL(chargebills.ChargeBillCount, 0) AS ChargeBillCount,
        ISNULL(chargebills.GeneratedApBillCount, 0) AS GeneratedApBillCount,
        CAST(CASE WHEN s.Status = ''Closed'' THEN 1 ELSE 0 END AS bit) AS IsLocked,
        ISNULL(s.ETA, CONVERT(date, s.CreatedAt)) AS SeqSortDate
    FROM dbo.Shipment AS s
    INNER JOIN dbo.Payee AS carrier ON carrier.PayeeId = s.PayeeId
    OUTER APPLY (
        SELECT TOP (1) NULLIF(LTRIM(RTRIM(c.CompanyCode)), '''') AS CompanyCode
        FROM dbo.Company AS c
        ORDER BY c.CompanyId
    ) AS company
    OUTER APPLY (
        SELECT SUM(ISNULL(sc.ChargeAmount, 0)) AS TotalCharges
        FROM dbo.ShipmentCharge AS sc
        WHERE sc.ShipmentId = s.ShipmentId
    ) AS ch
    OUTER APPLY (
        SELECT COUNT(*) AS AssignedBillCount
        FROM dbo.ShipmentPurchase AS sp
        WHERE sp.ShipmentId = s.ShipmentId
    ) AS assigned
    OUTER APPLY (
        SELECT
            COUNT(*) AS ChargeBillCount,
            SUM(CASE WHEN scb.PurchaseId IS NOT NULL THEN 1 ELSE 0 END) AS GeneratedApBillCount
        FROM dbo.ShipmentChargeBill AS scb
        WHERE scb.ShipmentId = s.ShipmentId
    ) AS chargebills
    OUTER APPLY (
        SELECT STRING_AGG(CONVERT(nvarchar(max), x.FactorPO), '' / '') WITHIN GROUP (ORDER BY x.FactorPO) AS FactorPO
        FROM (
            SELECT DISTINCT NULLIF(LTRIM(RTRIM(p.FactorPO)), '''') AS FactorPO
            FROM dbo.ShipmentPurchase AS sp
            INNER JOIN dbo.Purchase AS p ON p.PurchaseId = sp.PurchaseId
            WHERE sp.ShipmentId = s.ShipmentId
              AND NULLIF(LTRIM(RTRIM(p.FactorPO)), '''') IS NOT NULL
        ) AS x
    ) AS fpo
    OUTER APPLY (
        SELECT STRING_AGG(CONVERT(nvarchar(max), x.VendorDocNumber), '' / '') WITHIN GROUP (ORDER BY x.VendorDocNumber) AS VendorDocNumber
        FROM (
            SELECT DISTINCT NULLIF(LTRIM(RTRIM(p.VendorDocNumber)), '''') AS VendorDocNumber
            FROM dbo.ShipmentPurchase AS sp
            INNER JOIN dbo.Purchase AS p ON p.PurchaseId = sp.PurchaseId
            WHERE sp.ShipmentId = s.ShipmentId
              AND NULLIF(LTRIM(RTRIM(p.VendorDocNumber)), '''') IS NOT NULL
        ) AS x
    ) AS vdoc
    OUTER APPLY (
        SELECT STRING_AGG(CONVERT(nvarchar(max), x.ShipperName), '' / '') WITHIN GROUP (ORDER BY x.ShipperName) AS ShipperName
        FROM (
            SELECT DISTINCT NULLIF(LTRIM(RTRIM(v.PayeeName)), '''') AS ShipperName
            FROM dbo.ShipmentPurchase AS sp
            INNER JOIN dbo.Purchase AS p ON p.PurchaseId = sp.PurchaseId
            INNER JOIN dbo.Payee AS v ON v.PayeeId = p.PayeeId
            WHERE sp.ShipmentId = s.ShipmentId
              AND NULLIF(LTRIM(RTRIM(v.PayeeName)), '''') IS NOT NULL
        ) AS x
    ) AS shipper
    OUTER APPLY (
        SELECT STRING_AGG(CONVERT(nvarchar(max), x.CustomerName), '' / '') WITHIN GROUP (ORDER BY x.CustomerName) AS CustomerName
        FROM (
            SELECT DISTINCT
                CASE
                    WHEN ISNULL(p.IsDropShip, 0) = 1 AND cust.PayeeName IS NOT NULL THEN NULLIF(LTRIM(RTRIM(cust.PayeeName)), '''')
                    WHEN ISNULL(p.IsDropShip, 0) = 0 THEN company.CompanyCode
                    ELSE NULL
                END AS CustomerName
            FROM dbo.ShipmentPurchase AS sp
            INNER JOIN dbo.Purchase AS p ON p.PurchaseId = sp.PurchaseId
            LEFT JOIN dbo.Sales AS ds ON ds.SalesId = p.DropShipSalesId
            LEFT JOIN dbo.Payee AS cust ON cust.PayeeId = ds.ShipId
            WHERE sp.ShipmentId = s.ShipmentId
        ) AS x
        WHERE x.CustomerName IS NOT NULL
    ) AS customer
    OUTER APPLY (
        SELECT STRING_AGG(CONVERT(nvarchar(max), x.Cat0), '' / '') WITHIN GROUP (ORDER BY x.Cat0) AS MajorItem
        FROM (
            SELECT DISTINCT vc.Cat0
            FROM dbo.ShipmentPurchase AS sp
            INNER JOIN dbo.PurchaseDetail AS pd ON pd.PurchaseId = sp.PurchaseId
            INNER JOIN dbo.Item AS i ON i.ItemId = pd.ItemId
            LEFT JOIN dbo.View_Category AS vc ON vc.CategoryId = i.CategoryId
            WHERE sp.ShipmentId = s.ShipmentId
              AND pd.LineType = ''I''
              AND pd.ItemId IS NOT NULL
              AND vc.Cat0 IS NOT NULL
        ) AS x
    ) AS major
    WHERE 1 = 1
      AND (@StartDate IS NULL OR s.ETA >= @StartDate)
      AND (@EndDate IS NULL OR s.ETA <= @EndDate)
      AND (@PayeeId IS NULL OR s.PayeeId = @PayeeId)
      AND (@Filterby IS NULL OR LOWER(@Filterby) <> ''open'' OR s.Status <> ''Closed'')
      AND (
          @S IS NULL
          OR (@SearchNumber IS NOT NULL AND s.ShipmentId = @SearchNumber)
          OR s.ContainerNo LIKE ''%'' + @S + ''%''
          OR fpo.FactorPO LIKE ''%'' + @S + ''%''
          OR vdoc.VendorDocNumber LIKE ''%'' + @S + ''%''
          OR shipper.ShipperName LIKE ''%'' + @S + ''%''
          OR customer.CustomerName LIKE ''%'' + @S + ''%''
      )
)
';

    IF @IsCount = 1
    BEGIN
        SET @Sql += N'SELECT @RCount = COUNT(*) FROM Base;';

        EXEC sp_executesql
            @Sql,
            N'@S nvarchar(50), @SearchNumber int, @StartDate date, @EndDate date, @PayeeId int, @Filterby nvarchar(100), @RCount int OUTPUT',
            @S = @S,
            @SearchNumber = @SearchNumber,
            @StartDate = @StartDate,
            @EndDate = @EndDate,
            @PayeeId = @PayeeId,
            @Filterby = @Filterby,
            @RCount = @TotalCount OUTPUT;

        RETURN;
    END

    SET @Sql += N'
SELECT
    ContainerSeq,
    ShipmentId,
    ShipmentType,
    ContainerNo,
    ContainerType,
    PayeeId,
    PayeeName,
    Origin,
    Destination,
    ETD,
    ETA,
    Status,
    DutyStatus,
    Notes,
    TotalCharges,
    FactorPO,
    VendorDocNumber,
    ShipperName,
    MajorItem,
    CustomerName,
    AreChargesComplete,
    ChargesCompletedAt,
    ChargesCompletedBy,
    AssignedBillCount,
    ChargeBillCount,
    GeneratedApBillCount,
    IsLocked
FROM Base
ORDER BY ' + @OrderBy + N'
OFFSET @OffsetRows ROWS
FETCH NEXT @Pagesize ROWS ONLY;';

    DECLARE @OffsetRows INT = @Pagesize * (@Pageno - 1);

    EXEC sp_executesql
        @Sql,
        N'@S nvarchar(50), @SearchNumber int, @StartDate date, @EndDate date, @PayeeId int, @Filterby nvarchar(100), @OffsetRows int, @Pagesize int',
        @S = @S,
        @SearchNumber = @SearchNumber,
        @StartDate = @StartDate,
        @EndDate = @EndDate,
        @PayeeId = @PayeeId,
        @Filterby = @Filterby,
        @OffsetRows = @OffsetRows,
        @Pagesize = @Pagesize;
END
