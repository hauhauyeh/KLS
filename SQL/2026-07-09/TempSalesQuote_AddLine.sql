
-- ============================================================
-- TempSalesQuote_AddLine
-- 2026-07-09: add account/freight line support (LineType 'A').
--   '@'-prefixed code routes to the account path (mirrors
--   TempSales_AddLine): resolve Account by AccountCode/Name,
--   reject Asset(A)/Expense(X) class, insert LineType='A'.
--   Item path unchanged except it now stamps LineType='I'.
-- ============================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- KLS-4DP-B5-TempSalesQuote_AddLine: 4-decimal pricing Section B Phase-1 (storage/type widen, inert).
--   Layered onto developer's f1d30aa (account/freight-line support). Widen entered/config price carriers
--   @UnitPrice/@AcctPrice/@DefaultPrice/@ListPrice 2dp -> 4dp. Inert: prices are entered/config (P1, TargetPrice,
--   <=2dp today); ExtTotal = ROUND(@Qty*price,2) stays 2dp. @Qty stays (entered qty deferred).
CREATE OR ALTER PROCEDURE [dbo].[TempSalesQuote_AddLine]
    @PayeeId        INT,
    @SalesQuoteId   INT,
    @EmpId          INT,
    @ItemId         INT = NULL,
    @ItemCode       NVARCHAR(50) = NULL,
    @Qty            DECIMAL(18,2),
    -- 4dp widen: was DECIMAL(18,2)
    @UnitPrice      DECIMAL(18,4) = NULL,
    @Unit           NVARCHAR(50) = NULL,
    @Notes          NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NewId INT;

    -- ========================================================
    -- ACCOUNT PATH (LineType 'A') -- '@' prefix, no ItemId
    -- ========================================================
    IF @ItemId IS NULL AND LEFT(@ItemCode, 1) = '@'
    BEGIN
        DECLARE @ResolvedAccountId INT;

        -- AccountCode stores the '@' prefix (@ISALE, @BK53, ...)
        SELECT @ResolvedAccountId = a.AccountId
        FROM Account a
        WHERE a.AccountCode = @ItemCode AND a.Inactive = 0;

        IF @ResolvedAccountId IS NULL
            SELECT @ResolvedAccountId = a.AccountId
            FROM Account a
            WHERE a.AccountName = @ItemCode AND a.Inactive = 0;

        IF @ResolvedAccountId IS NULL
        BEGIN
            RAISERROR('Account not found.', 16, 1);
            RETURN;
        END

        -- Reject Asset (A) and Expense (X) class accounts
        IF EXISTS (
            SELECT 1
            FROM Account a
            INNER JOIN AccountCategory ac ON a.AccountCategoryId = ac.AccountCategoryId
            WHERE a.AccountId = @ResolvedAccountId AND ac.ClassCode IN ('A', 'X')
        )
        BEGIN
            RAISERROR('You can''t add Expense/Asset account', 16, 1);
            RETURN;
        END

        -- 4dp widen: was DECIMAL(18,2)
        DECLARE @AcctPrice DECIMAL(18,4) =
            CASE WHEN @UnitPrice IS NOT NULL AND @UnitPrice <> 0 THEN @UnitPrice ELSE 0 END;

        INSERT INTO TempSalesQuote (
            EmpId, SalesQuoteId, PayeeId, LineType, AccountId,
            OrdQty, UnitPrice, ExtTotal, FactorToBase,
            Notes, IsTaxable, ChangeStatus, IsStrike
        )
        VALUES (
            @EmpId, @SalesQuoteId, @PayeeId, 'A', @ResolvedAccountId,
            @Qty, @AcctPrice, ROUND(@Qty * ISNULL(@AcctPrice, 0), 2), NULL,
            @Notes, 0, 'I', 0
        );

        SET @NewId = SCOPE_IDENTITY();
        EXEC TempSalesQuote_GetList @EmpId, @PayeeId, @SalesQuoteId, NULL, NULL, @NewId;
        RETURN;
    END

    -- ========================================================
    -- ITEM PATH (LineType 'I')
    -- ========================================================
    IF @ItemId IS NULL AND @ItemCode IS NOT NULL
        SELECT @ItemId = ItemId FROM Item WHERE ItemCode = @ItemCode;

    IF @ItemId IS NULL
    BEGIN
        RAISERROR('Item not found.', 16, 1);
        RETURN;
    END

    DECLARE @ItemUnitId INT, @ResolvedUnit NVARCHAR(50), @FactorToBase DECIMAL(18,6);
    -- 4dp widen: were DECIMAL(18,2)
    DECLARE @DefaultPrice DECIMAL(18,4), @ListPrice DECIMAL(18,4);

    IF @Unit IS NOT NULL
    BEGIN
        SELECT TOP 1 @ItemUnitId = ItemUnitId, @ResolvedUnit = Unit, @FactorToBase = FactorToBase,
               @ListPrice = P1
        FROM ItemUnit WHERE ItemId = @ItemId AND Unit = @Unit;
    END

    IF @ItemUnitId IS NULL
    BEGIN
        SELECT TOP 1 @ItemUnitId = ItemUnitId, @ResolvedUnit = Unit, @FactorToBase = FactorToBase,
               @ListPrice = P1
        FROM ItemUnit WHERE ItemId = @ItemId AND IsBaseUnit = 1;
    END

    IF @UnitPrice IS NULL
    BEGIN
        SELECT @DefaultPrice = TargetPrice FROM ItemQuote
        WHERE PayeeId = @PayeeId AND ItemId = @ItemId AND ItemUnitId = @ItemUnitId AND Inactive = 0;

        SET @UnitPrice = ISNULL(@DefaultPrice, @ListPrice);
    END

    INSERT INTO TempSalesQuote (
        EmpId, SalesQuoteId, PayeeId, LineType, ItemId, ItemUnitId, Unit,
        OrdQty, UnitPrice, ExtTotal, FactorToBase,
        Notes, IsTaxable, ChangeStatus, IsStrike
    )
    VALUES (
        @EmpId, @SalesQuoteId, @PayeeId, 'I', @ItemId, @ItemUnitId, @ResolvedUnit,
        @Qty, @UnitPrice, ROUND(@Qty * ISNULL(@UnitPrice, 0), 2), ISNULL(@FactorToBase, 1),
        @Notes, (SELECT ISNULL(IsTaxable, 1) FROM Item WHERE ItemId = @ItemId), 'I', 0
    );

    SET @NewId = SCOPE_IDENTITY();
    EXEC TempSalesQuote_GetList @EmpId, @PayeeId, @SalesQuoteId, NULL, NULL, @NewId;
END
GO

