CREATE PROCEDURE [dbo].[Item_GetAllList]
	@Pageno INT,
	@Pagesize INT,
	@Search NVARCHAR(200),
	@StartDate DATE,
	@EndDate DATE,
	@VendorId INT,
	@Container NVARCHAR(50),
	@CategoryId INT = NULL,
	@Filterby NVARCHAR(50),
	@Id INT,
	@SortField NVARCHAR(50),
	@SortOrder NVARCHAR(50),
	@IsCount bit,
	@TotalCount INT OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Qry NVARCHAR(MAX);
	DECLARE @2year DATE = DATEADD(YEAR, -2, GETDATE());

	CREATE TABLE #itmtbl
	(
		Id INT IDENTITY(1,1),
		ItemId INT,
		ItemCode NVARCHAR(50),
		ItemName NVARCHAR(255),
		ItemName2 NVARCHAR(255),
		SetPacking NVARCHAR(100),
		LastCostDate DATE,
		ItemUnitId INT,
		BaseUnit NVARCHAR(50),
		BaseRecentCost DECIMAL(18,2),
		BaseP1 DECIMAL(18,2),
		SaftyInventory DECIMAL(18,2),
		PreferredVendorId INT,
		VendorName NVARCHAR(255),
		IsHighlighted BIT,
		Inactive BIT,
		ExpiryDate DATE,
		LCloseQty DECIMAL(18,2),
		LAvgCost DECIMAL(18,2),
		LInventoryValue DECIMAL(18,2),
		CaseWeight DECIMAL(18,2),
		Last3M DECIMAL(18,2),
		M0 DECIMAL(18,2),
		M1 DECIMAL(18,2),
		M2 DECIMAL(18,2),
		M3 DECIMAL(18,2),
		YTD DECIMAL(18,2),
		YTDSalesPercent DECIMAL(18,4),
		RecentCostPercent DECIMAL(18,4),
		FutureQty DECIMAL(18,2),
		OnHandQty DECIMAL(18,2),
		UpcomingQty DECIMAL(18,2),
		LastAdjDate DATE,
		PrimaryImageUrl NVARCHAR(300),
		CategoryId INT,
		FullCategoryPath NVARCHAR(500),
		StorageId INT,
		StorageName NVARCHAR(255)
	);

	IF @IsCount = 1
		SET @Qry = 'SELECT @RCount = COUNT(i.ItemId)';
	ELSE
		SET @Qry = 'SELECT
		i.ItemId,
        i.ItemCode,
        i.ItemName,
        i.ItemName2,
        i.SetPacking,
		NULL AS LastCostDate,
		bu.ItemUnitId,
		bu.Unit,
        bu.RecentCost,
        bu.P1,
		i.SaftyInventory,
        i.PreferredVendorId,
        p.PayeeName,
        i.IsHighlighted,
        i.Inactive,
        i.ExpiryDate,
		i.LCloseQty,
        i.LAvgCost,
        i.LInventoryValue,
        i.CaseWeight,
        i.Last3M,
        i.M0,
        i.M1,
        i.M2,
        i.M3,
        i.YTD,
        i.YTDSalesPercent,
		null AS RecentCostPercent,
		null AS FutureQty,
		NULL AS OnHandQty,
		NULL AS UpcomingQty,
		NULL AS LastAdjDate,
		im.ThumbnailPath,
		i.CategoryId,
		ISNULL(v.RootNode, '''') AS FullCategoryPath,
		i.StorageId,
		s.DisplayName AS StorageName';

	-- Base query with joins and filters
	SET @Qry += ' FROM Item AS i
	OUTER APPLY (
            SELECT Unit, RecentCost, P1, ItemUnitId
            FROM dbo.ItemUnit
            WHERE ItemId = i.ItemId AND IsBaseUnit = 1
        ) bu
	LEFT JOIN dbo.Payee p ON p.PayeeId = i.PreferredVendorId
	LEFT JOIN ItemImage im ON i.ItemId = im.ItemId AND im.IsPrimary=1
	LEFT JOIN View_Category v ON v.CategoryId = i.CategoryId
	LEFT JOIN ItemStorage s ON s.StorageId = i.StorageId
	WHERE ItemType IN (''Inventory'', ''NonInventory'') ';

	IF @Id IS NOT NULL
		SET @Qry += ' AND i.ItemId = ' + CONVERT(VARCHAR, @Id);
	ELSE IF @Filterby = 'delete'
		SET @Qry += ' AND i.IsDeleted = 1';
	ELSE
		SET @Qry += ' AND i.IsDeleted = 0';

	-- Search filter
	IF @Search IS NOT NULL
	BEGIN
		SET @Search = REPLACE(@Search, '''', '''''');
		SET @Qry += '
			AND (
				ItemCode = ''' + CONVERT(NVARCHAR(100), @Search) + ''' OR
				ItemName LIKE ''%' + CONVERT(NVARCHAR(100), @Search) + '%''
			) ';
	END

	-- Vendor-based filtering
	IF @VendorId IS NOT NULL
		SET @Qry += '
			AND i.ItemId IN (
				SELECT pd.ItemId
				FROM Purchase AS p
				INNER JOIN PurchaseDetail AS pd ON p.PurchaseId = pd.PurchaseId
				WHERE p.ArrivalDate >= ''' + CONVERT(VARCHAR, @2year, 101) + '''
				AND p.PayeeId = ' + CONVERT(VARCHAR, @VendorId) + '
			) ';

	-- Arrival date filtering
	IF @StartDate IS NOT NULL
		SET @Qry += '
			AND i.ItemId IN (
				SELECT pd.ItemId
				FROM Purchase AS p
				INNER JOIN PurchaseDetail AS pd ON p.PurchaseId = pd.PurchaseId
				WHERE p.ArrivalDate >= ''' + CONVERT(VARCHAR, @StartDate) + ''' AND p.ArrivalDate<='''+CONVERT(VARCHAR,@EndDate)+'''
			) ';

	-- Container filter
	IF @Container IS NOT NULL
		SET @Qry += '
			AND i.ItemId IN (
				SELECT pd.ItemId
				FROM Purchase AS p
				INNER JOIN PurchaseDetail AS pd ON p.PurchaseId = pd.PurchaseId
				WHERE p.ContainerNumber = ''' + @Container + '''
			) ';

	-- Category filter (includes all descendant categories)
	IF @CategoryId IS NOT NULL
	BEGIN
		DECLARE @CatIds NVARCHAR(MAX);
		;WITH CatTree AS (
			SELECT CategoryId FROM ItemCategory WHERE CategoryId = @CategoryId
			UNION ALL
			SELECT c.CategoryId FROM ItemCategory c INNER JOIN CatTree ct ON c.ParentId = ct.CategoryId
		)
		SELECT @CatIds = STRING_AGG(CONVERT(VARCHAR, CategoryId), ',') FROM CatTree;
		SET @Qry += ' AND i.CategoryId IN (' + @CatIds + ')';
	END

	-- Negative on-hand
	IF @FilterBy = 'negonhand'
		SET @Qry += ' AND LCloseQty < 0';

	-- In-stock filter
	IF @Filterby = 'instock'
		SET @Qry += ' AND LCloseQty > 0';

	-- if just counting
	IF @IsCount = 1
	BEGIN
		EXEC sp_executesql @Qry, N'@RCount INT OUTPUT', @RCount = @TotalCount OUTPUT;
		RETURN;
	END

	IF @SortField is not null
	BEGIN
		IF @SortField='cat'
			SET @Qry += ' ORDER BY v.RootNode, ItemName'
		ELSE IF @SortField='storage'
			SET @Qry += ' ORDER BY s.DisplayName, ItemName'
		ELSE IF @SortField='exp'
			SET @Qry += ' ORDER BY ExpiryDate'
		ELSE
			SET @Qry+=' ORDER BY '+@SortField+' '+@SortOrder+''
	END
	ELSE
		SET @Qry += ' ORDER BY i.Last3M DESC,ItemName'

	-- Pagination
	SET @Qry += '
		OFFSET ' + CONVERT(VARCHAR(100), (@PageSize * (@Pageno - 1))) + ' ROWS
		FETCH NEXT ' + CONVERT(VARCHAR(100), @Pagesize) + ' ROWS ONLY';

	-- Execute dynamic query into temp table
	INSERT INTO #itmtbl
	EXEC (@Qry);

	-- 1. Update FutureQty for future sales
	;WITH FutureSales AS (
		SELECT
			sd.ItemId,
			SUM(sd.BaseShipQty) AS Qty
		FROM Sales s
		INNER JOIN SalesDetail sd ON s.SalesId = sd.SalesId
		WHERE s.ShipDate > CONVERT(DATE, GETDATE())
		GROUP BY sd.ItemId
	)
	UPDATE m
	SET m.FutureQty = fs.Qty * -1
	FROM #itmtbl m
	INNER JOIN FutureSales fs ON m.ItemId = fs.ItemId;

	-- 2. Calculate OnHand = LCloseQty - FutureQty
	UPDATE #itmtbl
	SET OnHandQty = LCloseQty - ISNULL(FutureQty, 0);

	-- 3. Populate LastCostDate from View_RecentCost
	UPDATE m
	SET
		m.LastCostDate = r1.ArrivalDate
	FROM #itmtbl m
	LEFT JOIN View_RecentCost r1
		ON r1.ItemId = m.ItemId AND r1.RN = 1

	-- 4. Update Incoming (unreceived PO lines)
	;WITH IncomingPurchase AS (
		SELECT pd.ItemId, SUM(pd.OrdQty0) AS Qty
		FROM PurchaseDetail pd
		WHERE pd.ReceiveQty IS NULL AND pd.ItemId IS NOT NULL
		GROUP BY pd.ItemId
	)
	UPDATE m
	SET m.UpcomingQty = ip.Qty
	FROM #itmtbl m
	INNER JOIN IncomingPurchase ip ON m.ItemId = ip.ItemId;

	-- 5. Update LastAdjDate from InventoryAdj
	;WITH LastAdjDate AS (
		SELECT
			ad.ItemId,
			MAX(a.AdjDate) AS LastAdjDate
		FROM InventoryAdj a
		INNER JOIN InventoryAdjDetail ad ON a.AdjId = ad.AdjId
		INNER JOIN #itmtbl m ON m.ItemId = ad.ItemId
		GROUP BY ad.ItemId
	)
	UPDATE m
	SET m.LastAdjDate = l.LastAdjDate
	FROM #itmtbl m
	INNER JOIN LastAdjDate l ON m.ItemId = l.ItemId;

	-- Re-apply sort on final SELECT
	IF @SortField IS NOT NULL
	BEGIN
		IF @SortField = 'cat' OR @SortField = 'storage'
			SELECT * FROM #itmtbl ORDER BY Id
		ELSE IF @SortField = 'exp'
			SELECT * FROM #itmtbl ORDER BY ExpiryDate
		ELSE
		BEGIN
			DECLARE @FinalQry NVARCHAR(MAX) = 'SELECT * FROM #itmtbl ORDER BY ' + @SortField + ' ' + ISNULL(@SortOrder, 'ASC');
			EXEC(@FinalQry);
		END
	END
	ELSE
		SELECT * FROM #itmtbl ORDER BY Last3M DESC, ItemName

	DROP TABLE #itmtbl
END
