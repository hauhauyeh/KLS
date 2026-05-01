SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- TempSales_AddLine
-- Consolidated SP: item/account lookup + unit resolve + pricing + INSERT + return
-- Replaces 5 DB round-trips in TempSalesService.AddItem/AddAccount()
-- =============================================
CREATE PROCEDURE [dbo].[TempSales_AddLine]
    @PayeeId    INT,
    @SalesId    INT,
    @EmpId      INT,
    @ItemId     INT = NULL,
    @ItemCode   NVARCHAR(100) = NULL,
    @Qty        DECIMAL(18,4),
    @UnitPrice  DECIMAL(18,4) = NULL,
    @Unit       NVARCHAR(10) = NULL,
    @Notes      NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NewTempSalesId INT;

    -- =============================================
    -- Route: '@' prefix → account path, else → item path
    -- Matches TempSalesService.Create() routing logic
    -- =============================================
    IF @ItemId IS NULL AND LEFT(@ItemCode, 1) = '@'
    BEGIN
        -- ===========================================
        -- ACCOUNT PATH (LineType 'A')
        -- Matches AddAccount() in TempSalesService.cs
        -- ===========================================
        DECLARE @ResolvedAccountId INT;

        -- Lookup by AccountCode (AccountCode stores '@' prefix: @ISALE, @BK53, etc.)
        SELECT @ResolvedAccountId = a.AccountId
        FROM Account a
        WHERE a.AccountCode = @ItemCode AND a.Inactive = 0;

        -- Fallback: AccountName exact match
        IF @ResolvedAccountId IS NULL
            SELECT @ResolvedAccountId = a.AccountId
            FROM Account a
            WHERE a.AccountName = @ItemCode AND a.Inactive = 0;

        IF @ResolvedAccountId IS NULL
            THROW 50003, 'Account not found', 1;

        -- Validate: reject Asset (A) and Expense (X) class
        IF EXISTS (
            SELECT 1 FROM Account a
            INNER JOIN AccountCategory ac ON a.AccountCategoryId = ac.AccountCategoryId
            WHERE a.AccountId = @ResolvedAccountId AND ac.ClassCode IN ('A', 'X')
        )
            THROW 50004, 'You can''t add Expense/Asset account', 1;

        -- Price: user-provided if != 0, else 0 (no pricing SP for accounts)
        DECLARE @AcctPrice DECIMAL(18,4);
        IF @UnitPrice IS NOT NULL AND @UnitPrice != 0
            SET @AcctPrice = @UnitPrice;
        ELSE
            SET @AcctPrice = 0;

        -- INSERT (trigger assigns LineId)
        INSERT INTO TempSales (
            EmpId, SalesId, PayeeId, LineType, AccountId,
            OrdQty, ShipQty, BillQty,
            UnitPrice,
            ChangeStatus, CartLineType, IsSystemManaged
        ) VALUES (
            @EmpId, @SalesId, @PayeeId, 'A', @ResolvedAccountId,
            @Qty, @Qty, @Qty,
            @AcctPrice,
            'I', 'MAIN', 0
        );

        SET @NewTempSalesId = SCOPE_IDENTITY();

        -- Return shape must match TempSalesItem.
        SELECT t.*, CAST(NULL AS DATETIME) AS ParentShipDate, a.AccountName AS ItemName, a.AccountCode AS ItemCode,
               NULL AS CaseWeight, NULL AS PackSize, NULL AS LCloseQty, NULL AS BaseUnit
        FROM TempSales t
        INNER JOIN Account a ON t.AccountId = a.AccountId
        WHERE t.TempSalesId = @NewTempSalesId;
    END
    ELSE
    BEGIN
        -- ===========================================
        -- ITEM PATH (LineType 'I') — unchanged from Phase 1
        -- ===========================================
        DECLARE @ResolvedItemId INT;
        DECLARE @ResolvedItemUnitId INT;

        -- Step 1: Resolve item
        IF @ItemId IS NOT NULL
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM Item WHERE ItemId = @ItemId AND IsDeleted = 0)
                THROW 50001, 'Product code not found', 1;

            IF EXISTS (SELECT 1 FROM Item WHERE ItemId = @ItemId AND Inactive = 1)
                THROW 50002, 'This product already discontinue', 1;

            SET @ResolvedItemId = @ItemId;
        END
        ELSE
        BEGIN
            SELECT @ResolvedItemId = ItemId FROM Item
            WHERE ItemCode = @ItemCode AND IsDeleted = 0;

            IF @ResolvedItemId IS NULL
                SELECT @ResolvedItemId = ItemId FROM Item
                WHERE ItemName = @ItemCode AND IsDeleted = 0;

            IF @ResolvedItemId IS NULL
                THROW 50001, 'Product code not found', 1;

            IF EXISTS (SELECT 1 FROM Item WHERE ItemId = @ResolvedItemId AND Inactive = 1)
                THROW 50002, 'This product already discontinue', 1;
        END

        -- Step 2: Resolve unit string -> ItemUnitId
        IF @Unit IS NOT NULL AND LTRIM(RTRIM(@Unit)) != ''
        BEGIN
            DECLARE @UnitLower NVARCHAR(10) = LOWER(LTRIM(RTRIM(@Unit)));

            IF @UnitLower = 'w'
            BEGIN
                SELECT TOP 1 @ResolvedItemUnitId = ItemUnitId
                FROM ItemUnit
                WHERE ItemId = @ResolvedItemId AND Inactive = 0
                ORDER BY IsBaseUnit DESC, ItemUnitId ASC;
            END
            ELSE IF @UnitLower = 'r'
            BEGIN
                SELECT TOP 1 @ResolvedItemUnitId = ItemUnitId
                FROM ItemUnit
                WHERE ItemId = @ResolvedItemId AND Inactive = 0
                ORDER BY IsBaseUnit ASC, ItemUnitId ASC;
            END
            ELSE
            BEGIN
                SELECT TOP 1 @ResolvedItemUnitId = ItemUnitId
                FROM ItemUnit
                WHERE ItemId = @ResolvedItemId AND Inactive = 0 AND Unit = @Unit;

                IF @ResolvedItemUnitId IS NULL
                    SELECT TOP 1 @ResolvedItemUnitId = ItemUnitId
                    FROM ItemUnit
                    WHERE ItemId = @ResolvedItemId AND Inactive = 0
                    ORDER BY IsBaseUnit DESC, ItemUnitId ASC;
            END
        END

        -- Step 3: Pricing
        DECLARE @PriceResult TABLE (
            [ItemId]        INT,
            [ItemUnitId]    INT,
            [DefaultUnit]   NVARCHAR(50),
            [DefaultPrice]  DECIMAL(18,2),
            [FactorToBase]  DECIMAL(18,6),
            [IsTaxable]     BIT,
            [OrgPrice]      DECIMAL(18,2),
            [Discount]      DECIMAL(18,2)
        );

        INSERT INTO @PriceResult
        EXEC [Get_ItemPriceByCustomer] @PayeeId, @ResolvedItemId, @ResolvedItemUnitId;

        DECLARE @PriceItemUnitId INT;
        DECLARE @PriceDefaultUnit NVARCHAR(50);
        DECLARE @PriceDefaultPrice DECIMAL(18,2);
        DECLARE @PriceFactorToBase DECIMAL(18,6);
        DECLARE @PriceIsTaxable BIT;
        DECLARE @PriceOrgPrice DECIMAL(18,2);
        DECLARE @PriceDiscount DECIMAL(18,2);

        SELECT
            @PriceItemUnitId = ItemUnitId,
            @PriceDefaultUnit = DefaultUnit,
            @PriceDefaultPrice = DefaultPrice,
            @PriceFactorToBase = FactorToBase,
            @PriceIsTaxable = IsTaxable,
            @PriceOrgPrice = OrgPrice,
            @PriceDiscount = Discount
        FROM @PriceResult;

        DECLARE @FinalPrice DECIMAL(18,4);
        IF @UnitPrice IS NOT NULL AND @UnitPrice != 0
            SET @FinalPrice = @UnitPrice;
        ELSE
            SET @FinalPrice = ISNULL(@PriceDefaultPrice, 0);

        -- Step 4: INSERT
        INSERT INTO TempSales (
            EmpId, SalesId, PayeeId, LineType, ItemId,
            ItemUnitId, Unit, FactorToBase,
            OrdQty, ShipQty, BillQty,
            UnitPrice, Notes,
            IsTaxable, OrgPrice, DiscountPercent,
            ChangeStatus, CartLineType, IsSystemManaged
        ) VALUES (
            @EmpId, @SalesId, @PayeeId, 'I', @ResolvedItemId,
            @PriceItemUnitId, @PriceDefaultUnit, @PriceFactorToBase,
            @Qty, @Qty, @Qty,
            @FinalPrice, @Notes,
            @PriceIsTaxable, @PriceOrgPrice, @PriceDiscount,
            'I', 'MAIN', 0
        );

        SET @NewTempSalesId = SCOPE_IDENTITY();

        -- Return shape must match TempSalesItem.
        SELECT t.*, CAST(NULL AS DATETIME) AS ParentShipDate, i.ItemName, i.ItemCode, i.CaseWeight, i.PackSize,
               i.LCloseQty, bu.Unit AS BaseUnit
        FROM TempSales t
        INNER JOIN Item i ON t.ItemId = i.ItemId
        LEFT JOIN ItemUnit bu ON i.ItemId = bu.ItemId AND bu.IsBaseUnit = 1 AND bu.Inactive = 0
        WHERE t.TempSalesId = @NewTempSalesId;
    END
END
