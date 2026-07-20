-- =============================================================================
-- Report_InvoiceDetail -- deploy (CREATE OR ALTER). Working file per SP workflow.
-- 2026-07-18 UNCAT-PRINT: an item with no category (CategoryId NULL, or root missing
--   from #CatTbl) matched no loop iteration and silently vanished from the printed
--   invoice while still counting in the invoice total. Two edits, nothing else:
--   (1) sentinel 'OTHER' row appended to #CatTbl (before @MaxRow count) when such
--       lines exist -- IDENTITY makes it the last iteration, so OTHER prints after
--       all real category groups;
--   (2) loop predicate: sentinel iteration (@Cat0 NULL) picks up exactly the items
--       no other iteration claimed. Real iterations reduce to the old v.Cat0=@Cat0
--       (the old "@Cat0 IS NULL" arm was dead code -- @Cat0 is never NULL for real
--       #CatTbl rows). Header emission / PACKED ITEM / singleton cleanup untouched.
-- Baseline: KLS/SQL/2026-07-18/Report_InvoiceDetail_live_baseline.sql
-- Plan: plan/report-invoicedetail-uncategorized-v2.md
-- =============================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Report_InvoiceDetail] -- [Report_InvoiceDetail] 68126

    @SalesId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ITEM_DEFAULT_SORTORDER NVARCHAR(50)

    SELECT @ITEM_DEFAULT_SORTORDER=SettingValue FROM SystemSetting WHERE SettingKey = 'ITEM_DEFAULT_SORTORDER'

    CREATE TABLE #TempInvoice
    (
        AutoId           INT IDENTITY(1,1),
        ItemCode         NVARCHAR(50),
        ItemName         NVARCHAR(255),
        ItemName2        NVARCHAR(255),
        PackSize         NVARCHAR(100),
        LineType         NVARCHAR(1),
        ItemUnitId       INT,
        Unit             NVARCHAR(50),
        UnitPrice        DECIMAL(18,2),
        ShipQty          DECIMAL(18,2),
        BillQty          DECIMAL(18,2),
        ExtTotal         DECIMAL(18,2),
        BaseShipQty      DECIMAL(18,6),
        Notes            NVARCHAR(300),
        IsGroup          BIT,
        IsRetail         INT DEFAULT (0),
        GroupName        NVARCHAR(255),
        ItemWeight       DECIMAL(18,2),
        AisleNum         NVARCHAR(50),
        BayNum           NVARCHAR(50),
        Barcode          NVARCHAR(200),
        FIFOHistory      NVARCHAR(MAX),
        FIFOHistoryOrder NVARCHAR(MAX),
        CatInvoiceDesc   NVARCHAR(200),
        IsTaxable        BIT,
        ListPrice        DECIMAL(18,2)
    );

    CREATE TABLE #CatTbl
    (
        CatAutoId    INT IDENTITY(1,1),
        CatId        INT,
        Cat0         NVARCHAR(255),
        DisplayText  NVARCHAR(255),
        InvoiceName  NVARCHAR(255)
    );

    -- Insert into #CatTbl, ordered by original CatName
    INSERT INTO #CatTbl (CatId,Cat0,DisplayText,InvoiceName)
    SELECT
    x.CategoryId,
    x.Cat0,
    x.DisplayText,
    x.InvoiceName
    FROM
    (
        SELECT DISTINCT
            vc.SortOrder,
            vc.CategoryId,
            vc.CategoryName AS Cat0,
            ISNULL(vc.DisplayName, vc.CategoryName) + ' ' + ISNULL(vc.ForeignName, '') AS DisplayText,
            vc.InvoiceName
        FROM SalesDetail sd
        INNER JOIN Item i ON sd.ItemId = i.ItemId
        INNER JOIN View_Category v ON v.CategoryId = i.CategoryId
        INNER JOIN View_Category vc
            ON vc.CategoryName = v.Cat0
           AND vc.TreeLevel = 0
        WHERE sd.SalesId = @SalesId
    ) x
    ORDER BY x.SortOrder, x.Cat0;

    -- 2026-07-18 UNCAT-PRINT: items whose category is missing (CategoryId NULL) or whose root
    -- never made it into #CatTbl would match no loop iteration and vanish from the printed
    -- invoice while still counting in the total. Add a sentinel group so they print last.
    IF EXISTS (
        SELECT 1
        FROM SalesDetail sd
        INNER JOIN Item i ON sd.ItemId = i.ItemId
        LEFT JOIN View_Category v ON v.CategoryId = i.CategoryId
        WHERE sd.SalesId = @SalesId
          AND (v.Cat0 IS NULL OR NOT EXISTS (SELECT 1 FROM #CatTbl c WHERE c.Cat0 = v.Cat0))
    )
    INSERT INTO #CatTbl (CatId, Cat0, DisplayText, InvoiceName)
    VALUES (NULL, NULL, N'OTHER', NULL);

    DECLARE @RowNum       INT;
    DECLARE @MaxRow       INT;
    DECLARE @Cat0         NVARCHAR(255);
    DECLARE @DisplayText  NVARCHAR(255);
    DECLARE @InvoiceName  NVARCHAR(255);
    DECLARE @IsPackedItem INT;

    SELECT @MaxRow = COUNT(CatAutoId) FROM #CatTbl;
    SELECT @RowNum = 1;

    WHILE @RowNum <= @MaxRow
    BEGIN
        SELECT
            @Cat0         = c.Cat0,
            @DisplayText  = c.DisplayText,
            @InvoiceName  = c.InvoiceName
        FROM #CatTbl AS c
        WHERE c.CatAutoId = @RowNum;

        IF @DisplayText IS NOT NULL
        BEGIN
            INSERT INTO #TempInvoice (ItemName, IsGroup, GroupName, CatInvoiceDesc, IsTaxable)
            VALUES (@DisplayText, 1, @DisplayText, @InvoiceName, 0);
        END

        INSERT INTO #TempInvoice
        SELECT
            i.ItemCode,
            i.ItemName,
            i.ItemName2,
            i.PackSize,
            sd.LineType,
            sd.ItemUnitId,
            sd.Unit,
            sd.UnitPrice,
            sd.ShipQty,
            sd.BillQty,
            (sd.BillQty * sd.UnitPrice) AS ExtTotal,
            sd.BaseShipQty,
            sd.Notes,
            --p.ItemDescX1,
            0,
            CASE WHEN sd.Unit <> 'cs' AND sd.Unit <> 'lbs' THEN 1 ELSE 0 END,
            @DisplayText,
            sd.BaseShipQty*i.CaseWeight,
            s.Aisle,
            s.Bay,
            (SELECT * FROM dbo.Fn_GetUPC(iu.Barcode)),
            STUFF(sd.FIFOHistory, 1, CHARINDEX('@', sd.FIFOHistory), ''),
            STUFF(sd.FIFOHistoryOrder, 1, CHARINDEX('@', sd.FIFOHistoryOrder), ''),
            null,
            sd.IsTaxable,
            iu.P1
        FROM SalesDetail sd
        INNER JOIN Item i ON sd.ItemId = i.ItemId
        INNER JOIN ItemUnit iu ON iu.ItemUnitId = sd.ItemUnitId
        LEFT JOIN View_Category v ON v.CategoryId = i.CategoryId
        LEFT JOIN ItemStorage s ON s.StorageId = i.StorageId
        WHERE sd.SalesId = @SalesId
          -- 2026-07-18 UNCAT-PRINT old predicate: AND (@Cat0 IS NULL OR v.Cat0 = @Cat0)
          -- Real iterations (@Cat0 set) behave identically; the sentinel iteration (@Cat0 NULL)
          -- claims exactly the items no other iteration matched.
          AND (
                  v.Cat0 = @Cat0
               OR (@Cat0 IS NULL AND (v.Cat0 IS NULL OR NOT EXISTS (SELECT 1 FROM #CatTbl c WHERE c.Cat0 = v.Cat0)))
              )
        ORDER BY
        CASE WHEN @ITEM_DEFAULT_SORTORDER = 'NAME'  THEN i.ItemName END,
        CASE WHEN @ITEM_DEFAULT_SORTORDER = 'CODE'  THEN i.ItemCode END

        SET @RowNum += 1;
    END

    SELECT @IsPackedItem = COUNT(AutoId)
    FROM #TempInvoice
    WHERE IsRetail = 1;

    IF @IsPackedItem > 0
    BEGIN
        INSERT INTO #TempInvoice (ItemName, IsGroup, GroupName, IsTaxable)
        VALUES ('PACKED ITEM', 1, 'PACKED ITEM', 0);

        INSERT INTO #TempInvoice
        SELECT
            ItemCode,
            ItemName,
            ItemName2,
            PackSize,
            LineType,
            ItemUnitId,
            Unit,
            UnitPrice,
            ShipQty,
            BillQty,
            ExtTotal,
            BaseShipQty,
            Notes,
            0            AS IsGroup,
            0            AS IsRetail,
            'PACKED ITEM' AS GroupName,
            ItemWeight,
            AisleNum,
            BayNum,
            Barcode,
            FIFOHistory,
            FIFOHistoryOrder,
            NULL         AS CatInvoiceDesc,
            IsTaxable,
            ListPrice
        FROM #TempInvoice
        WHERE IsRetail = 1
        ORDER BY
        CASE WHEN @ITEM_DEFAULT_SORTORDER = 'NAME'  THEN ItemName END,
        CASE WHEN @ITEM_DEFAULT_SORTORDER = 'CODE'  THEN ItemCode END

        DELETE FROM #TempInvoice
        WHERE IsRetail = 1;
    END

    DELETE FROM #TempInvoice
    WHERE GroupName IN
    (
        SELECT GroupName
        FROM #TempInvoice
        GROUP BY GroupName
        HAVING COUNT(GroupName) = 1
    );

    INSERT INTO #TempInvoice (LineType,ItemName,UnitPrice,ShipQty,BillQty,ExtTotal,Notes,IsGroup, IsTaxable)
    SELECT
        sd.LineType,
        a.AccountName,
        sd.UnitPrice,
        sd.ShipQty,
        sd.BillQty,
        (sd.BillQty * sd.UnitPrice) AS ExtTotal,
        sd.Notes,
        0,
        0
    FROM SalesDetail AS sd
    INNER JOIN Account AS a ON sd.AccountId = a.AccountId
    WHERE sd.SalesId = @SalesId;

    SELECT * FROM #TempInvoice
    ORDER BY AutoId;

    DROP TABLE #TempInvoice;
    DROP TABLE #CatTbl;
END
