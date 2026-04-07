
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
	@TotalCount INT OUTPUT,
	@Visibility NVARCHAR(20) = NULL
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
		StorageName NVARCHAR(255),
		ActualSaftyInventory DECIMAL(18,2),
		RefillInventory DECIMAL(18,2),
		CaseLength DECIMAL(18,2),
		CaseWidth DECIMAL(18,2),
		CaseHeight DECIMAL(18,2),
		CaseVolumeInCubicMeter DECIMAL(18,4),
		IsVolumeManual BIT
	);

	IF @IsCount = 1
		SET @Qry = 'SELECT @RCount = COUNT(i.ItemId)';
	ELSE
		SET @Qry = 'SELECT
		i.ItemId, i.ItemCode, i.ItemName, i.ItemName2, i.SetPacking,
		NULL AS LastCostDate, bu.ItemUnitId, bu.Unit, bu.RecentCost, bu.P1,
		i.SaftyInventory, i.PreferredVendorId, p.PayeeName, i.IsHighlighted, i.Inactive,
		i.ExpiryDate, i.LCloseQty, i.LAvgCost, i.LInventoryValue, i.CaseWeight,
		i.Last3M, i.M0, i.M1, i.M2, i.M3, i.YTD, i.YTDSalesPercent,
		null AS RecentCostPercent, null AS FutureQty, NULL AS OnHandQty,
		NULL AS UpcomingQty, NULL AS LastAdjDate, CASE WHEN im.ImageId IS NOT NULL AND im.Has300 = 1 THEN ''/Images/items/'' + CAST(im.ItemId AS VARCHAR(10)) + ''/'' + CAST(im.ImageIndex AS VARCHAR(10)) + ''-300.png'' ELSE NULL END,
		i.CategoryId, ISNULL(v.RootNode, '''') AS FullCategoryPath,
		i.StorageId, s.DisplayName AS StorageName,
		i.ActualSaftyInventory, i.RefillInventory,
		i.CaseLength, i.CaseWidth, i.CaseHeight, i.CaseVolumeInCubicMeter, i.IsVolumeManual';

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
	ELSE IF @Visibility = 'deleted'
		SET @Qry += ' AND i.IsDeleted = 1';
	ELSE IF @Visibility = 'inactive'
		SET @Qry += ' AND i.IsDeleted = 0 AND i.Inactive = 1';
	ELSE IF @Visibility = 'active'
		SET @Qry += ' AND i.IsDeleted = 0 AND i.Inactive = 0';
	ELSE
		SET @Qry += ' AND i.IsDeleted = 0';

	IF @Search IS NOT NULL
	BEGIN
		SET @Search = REPLACE(@Search, '''', '''''');
		SET @Qry += '
			AND (
				ItemCode = ''' + CONVERT(NVARCHAR(100), @Search) + ''' OR
				ItemName LIKE ''%' + CONVERT(NVARCHAR(100), @Search) + '%''
			) ';
	END

	IF @VendorId IS NOT NULL
		SET @Qry += '
			AND i.ItemId IN (
				SELECT pd.ItemId
				FROM Purchase AS p
				INNER JOIN PurchaseDetail AS pd ON p.PurchaseId = pd.PurchaseId
				WHERE p.ArrivalDate >= ''' + CONVERT(VARCHAR, @2year, 101) + '''
				AND p.P
