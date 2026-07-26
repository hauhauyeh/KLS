SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[ItemQuoteManager_GetList] -- EXEC dbo.ItemQuoteManager_GetList @EmpId = 100050, @PayeeId = 302017
    @EmpId INT,
    @PayeeId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ShareQuoteId INT;
    DECLARE @IsLinkOwnShared BIT = 0;
    DECLARE @BaseMarkup DECIMAL(18,4) = 0;
    DECLARE @SharedBaseMarkup DECIMAL(18,4) = 0;
    DECLARE @IsShareBasePrice BIT = 0;
    DECLARE @IsBaseToRecentCost BIT = 0;
    DECLARE @PriceDecimals INT = 2;
    DECLARE @IsPriceRoundup BIT = 0;

    SELECT
        @ShareQuoteId = c.ShareQuoteId,
        @IsLinkOwnShared = ISNULL(c.IsLinkOwnShared, 0),
        @BaseMarkup = ISNULL(c.BaseMarkup, 0),
        @IsShareBasePrice = ISNULL(c.IsShareBasePrice, 0),
        @IsBaseToRecentCost = ISNULL(c.IsBaseToRecentCost, 0)
    FROM dbo.Customer c
    WHERE c.PayeeId = @PayeeId;

    SELECT @SharedBaseMarkup = ISNULL(c.BaseMarkup, 0)
    FROM dbo.Customer c
    WHERE c.PayeeId = @ShareQuoteId;

    SELECT @PriceDecimals = TRY_CAST(ss.SettingValue AS INT)
    FROM dbo.SystemSetting ss
    WHERE ss.SettingKey = 'PRICE_DISPLAY_DECIMALS';

    SET @PriceDecimals = CASE WHEN @PriceDecimals = 4 THEN 4 ELSE 2 END;

    SELECT @IsPriceRoundup = ISNULL(TRY_CAST(ss.SettingValue AS BIT), 0)
    FROM dbo.SystemSetting ss
    WHERE ss.SettingKey = 'ITEM_PRICE_ROUNDUP';

    ;WITH CustomerItemSales90 AS (
        SELECT
            sd.ItemId,
            CustomerLast3MAmount = SUM(sd.ShipQty * ISNULL(sd.UnitPrice, 0))
        FROM dbo.Sales s
        INNER JOIN dbo.SalesDetail sd ON sd.SalesId = s.SalesId
        WHERE s.ShipId = @PayeeId
          AND s.ShipDate >= DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
          AND sd.ItemId IS NOT NULL
          AND sd.ShipQty > 0
        GROUP BY sd.ItemId
    ),
    OwnRows AS (
        SELECT
            RowKey = CONCAT('O:', t.TempQuoteId),
            Source = CASE WHEN shared.ItemQuoteId IS NULL THEN 'Own' ELSE 'Own Override' END,
            IsEditable = CONVERT(BIT, 1),
            IsSharedVisibleInCustomerGuide = CONVERT(BIT, CASE WHEN @ShareQuoteId IS NOT NULL AND @IsLinkOwnShared = 1 THEN 1 ELSE 0 END),
            PayeeId = t.PayeeId,
            ShareQuoteId = @ShareQuoteId,
            t.ItemId,
            t.ItemUnitId,
            TempQuoteId = CONVERT(INT, t.TempQuoteId),
            OwnItemQuoteId = own.ItemQuoteId,
            SharedItemQuoteId = shared.ItemQuoteId,
            i.ItemCode,
            i.ItemName,
            i.CategoryId,
            FullCategoryPath = ISNULL(vc.RootNode, ''),
            CustomerLast3MAmount = ISNULL(sales90.CustomerLast3MAmount, 0),
            iu.Unit,
            iu.RecentCost,
            iu.P1,
            BaseMarkup = @BaseMarkup,
            IsBaseToRecentCost = @IsBaseToRecentCost,
            IsShareBasePrice = @IsShareBasePrice,
            SharedBaseMarkup = @SharedBaseMarkup,
            BasePrice = basePrice.Price,
            BasePriceSource = CASE WHEN @IsBaseToRecentCost = 1 THEN 'Recent Cost' ELSE 'P1' END,
            BaseMarkupPrice = baseWithCustomerRules.Price,
            BaseMarkupSource = CASE
                WHEN @IsShareBasePrice = 1 AND @SharedBaseMarkup <> 0 THEN 'Shared Base Markup'
                WHEN @BaseMarkup <> 0 THEN 'Own Base Markup'
                ELSE 'None'
            END,
            OwnMarkupPercent = t.MarkupPercent,
            OwnTargetPrice = t.TargetPrice,
            OwnIsFixed = t.IsFixed,
            SharedMarkupPercent = shared.MarkupPercent,
            SharedTargetPrice = shared.TargetPrice,
            SharedIsFixed = CONVERT(BIT, ISNULL(shared.IsFixed, 0)),
            MarkupPercent = t.MarkupPercent,
            TargetPrice = t.TargetPrice,
            IsFixed = t.IsFixed,
            FinalPrice = effective.FinalPrice,
            FinalPriceReason = reason.FinalPriceReason
        FROM dbo.TempItemQuote t
        INNER JOIN dbo.Item i ON i.ItemId = t.ItemId
        INNER JOIN dbo.ItemUnit iu ON iu.ItemUnitId = t.ItemUnitId
        LEFT JOIN dbo.View_Category vc ON vc.CategoryId = i.CategoryId
        LEFT JOIN CustomerItemSales90 sales90 ON sales90.ItemId = t.ItemId
        OUTER APPLY (
            SELECT TOP (1) iq.ItemQuoteId
            FROM dbo.ItemQuote iq
            WHERE iq.PayeeId = @PayeeId
              AND iq.ItemUnitId = t.ItemUnitId
        ) own
        OUTER APPLY (
            SELECT TOP (1)
                iq.ItemQuoteId,
                iq.MarkupPercent,
                iq.TargetPrice,
                iq.IsFixed
            FROM dbo.ItemQuote iq
            WHERE iq.PayeeId = @ShareQuoteId
              AND iq.ItemUnitId = t.ItemUnitId
        ) shared
        CROSS APPLY (
            SELECT Price = CASE WHEN @IsBaseToRecentCost = 1 THEN ISNULL(iu.RecentCost, 0) ELSE ISNULL(iu.P1, 0) END
        ) basePrice
        CROSS APPLY (
            SELECT Price = CASE WHEN @BaseMarkup <> 0 THEN ROUND(basePrice.Price * (1 + @BaseMarkup), @PriceDecimals) ELSE basePrice.Price END
        ) ownBase
        CROSS APPLY (
            SELECT Price = CASE WHEN @IsShareBasePrice = 1 AND @SharedBaseMarkup <> 0 THEN ROUND(basePrice.Price * (1 + @SharedBaseMarkup), @PriceDecimals) ELSE ownBase.Price END
        ) baseWithCustomerRules
        CROSS APPLY (
            SELECT Price = CASE WHEN ISNULL(shared.TargetPrice, 0) <> 0 THEN shared.TargetPrice ELSE baseWithCustomerRules.Price END
        ) afterSharedTarget
        CROSS APPLY (
            SELECT Price = CASE WHEN ISNULL(t.TargetPrice, 0) <> 0 THEN t.TargetPrice ELSE afterSharedTarget.Price END
        ) afterOwnTarget
        CROSS APPLY (
            SELECT Price = CASE WHEN t.MarkupPercent IS NOT NULL THEN ROUND(basePrice.Price * (1 + t.MarkupPercent), @PriceDecimals) ELSE afterOwnTarget.Price END
        ) afterOwnMarkup
        CROSS APPLY (
            SELECT Price = ISNULL(ROUND(afterOwnMarkup.Price, @PriceDecimals), 0)
        ) beforeRoundup
        OUTER APPLY dbo.Fn_RoundUp(beforeRoundup.Price) rounded
        CROSS APPLY (
            SELECT FinalPrice = CASE WHEN @IsPriceRoundup = 1 THEN rounded.RoundedPrice ELSE beforeRoundup.Price END
        ) effective
        CROSS APPLY (
            SELECT FinalPriceReason = CASE
                WHEN t.MarkupPercent IS NOT NULL THEN 'Own Markup'
                WHEN ISNULL(t.TargetPrice, 0) <> 0 THEN 'Own Target'
                WHEN ISNULL(shared.TargetPrice, 0) <> 0 THEN 'Shared Target'
                WHEN @IsShareBasePrice = 1 AND @SharedBaseMarkup <> 0 THEN 'Shared Base Markup'
                WHEN @BaseMarkup <> 0 THEN 'Base Markup'
                ELSE 'Base'
            END
        ) reason
        WHERE t.EmpId = @EmpId
          AND t.PayeeId = @PayeeId
    ),
    SharedRows AS (
        SELECT
            RowKey = CONCAT('S:', shared.ItemQuoteId),
            Source = 'Shared',
            IsEditable = CONVERT(BIT, 0),
            IsSharedVisibleInCustomerGuide = CONVERT(BIT, CASE WHEN @IsLinkOwnShared = 1 THEN 1 ELSE 0 END),
            PayeeId = @PayeeId,
            ShareQuoteId = @ShareQuoteId,
            shared.ItemId,
            shared.ItemUnitId,
            TempQuoteId = CONVERT(INT, NULL),
            OwnItemQuoteId = CONVERT(INT, NULL),
            SharedItemQuoteId = shared.ItemQuoteId,
            i.ItemCode,
            i.ItemName,
            i.CategoryId,
            FullCategoryPath = ISNULL(vc.RootNode, ''),
            CustomerLast3MAmount = ISNULL(sales90.CustomerLast3MAmount, 0),
            iu.Unit,
            iu.RecentCost,
            iu.P1,
            BaseMarkup = @BaseMarkup,
            IsBaseToRecentCost = @IsBaseToRecentCost,
            IsShareBasePrice = @IsShareBasePrice,
            SharedBaseMarkup = @SharedBaseMarkup,
            BasePrice = basePrice.Price,
            BasePriceSource = CASE WHEN @IsBaseToRecentCost = 1 THEN 'Recent Cost' ELSE 'P1' END,
            BaseMarkupPrice = baseWithCustomerRules.Price,
            BaseMarkupSource = CASE
                WHEN @IsShareBasePrice = 1 AND @SharedBaseMarkup <> 0 THEN 'Shared Base Markup'
                WHEN @BaseMarkup <> 0 THEN 'Own Base Markup'
                ELSE 'None'
            END,
            OwnMarkupPercent = CONVERT(DECIMAL(18,4), NULL),
            OwnTargetPrice = CONVERT(DECIMAL(18,4), NULL),
            OwnIsFixed = CONVERT(BIT, 0),
            SharedMarkupPercent = shared.MarkupPercent,
            SharedTargetPrice = shared.TargetPrice,
            SharedIsFixed = shared.IsFixed,
            MarkupPercent = shared.MarkupPercent,
            TargetPrice = shared.TargetPrice,
            IsFixed = shared.IsFixed,
            FinalPrice = price.Price,
            FinalPriceReason = CASE
                WHEN shared.MarkupPercent IS NOT NULL THEN 'Shared Markup'
                WHEN ISNULL(shared.TargetPrice, 0) <> 0 THEN 'Shared Target'
                WHEN @IsShareBasePrice = 1 AND @SharedBaseMarkup <> 0 THEN 'Shared Base Markup'
                WHEN @BaseMarkup <> 0 THEN 'Base Markup'
                ELSE 'Base'
            END
        FROM dbo.ItemQuote shared
        INNER JOIN dbo.Item i ON i.ItemId = shared.ItemId
        INNER JOIN dbo.ItemUnit iu ON iu.ItemUnitId = shared.ItemUnitId
        LEFT JOIN dbo.View_Category vc ON vc.CategoryId = i.CategoryId
        LEFT JOIN CustomerItemSales90 sales90 ON sales90.ItemId = shared.ItemId
        CROSS APPLY (
            SELECT Price = CASE WHEN @IsBaseToRecentCost = 1 THEN ISNULL(iu.RecentCost, 0) ELSE ISNULL(iu.P1, 0) END
        ) basePrice
        CROSS APPLY (
            SELECT Price = CASE WHEN @BaseMarkup <> 0 THEN ROUND(basePrice.Price * (1 + @BaseMarkup), @PriceDecimals) ELSE basePrice.Price END
        ) ownBase
        CROSS APPLY (
            SELECT Price = CASE WHEN @IsShareBasePrice = 1 AND @SharedBaseMarkup <> 0 THEN ROUND(basePrice.Price * (1 + @SharedBaseMarkup), @PriceDecimals) ELSE ownBase.Price END
        ) baseWithCustomerRules
        OUTER APPLY dbo.Fn_GetPrice(@PayeeId, shared.ItemId, shared.ItemUnitId) price
        WHERE shared.PayeeId = @ShareQuoteId
          AND @ShareQuoteId IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM dbo.TempItemQuote own
              WHERE own.EmpId = @EmpId
                AND own.PayeeId = @PayeeId
                AND own.ItemUnitId = shared.ItemUnitId
          )
    ),
    AllRows AS (
        SELECT
            RowKey, Source, IsEditable, IsSharedVisibleInCustomerGuide,
            PayeeId, ShareQuoteId, ItemId, ItemUnitId, TempQuoteId,
            OwnItemQuoteId, SharedItemQuoteId, ItemCode, ItemName,
            CategoryId, FullCategoryPath, CustomerLast3MAmount,
            Unit, RecentCost, P1, BaseMarkup, IsBaseToRecentCost,
            IsShareBasePrice, SharedBaseMarkup, BasePrice, BasePriceSource,
            BaseMarkupPrice, BaseMarkupSource,
            OwnMarkupPercent, OwnTargetPrice, OwnIsFixed,
            SharedMarkupPercent, SharedTargetPrice, SharedIsFixed,
            MarkupPercent, TargetPrice, IsFixed, FinalPrice, FinalPriceReason
        FROM OwnRows

        UNION ALL

        SELECT
            RowKey, Source, IsEditable, IsSharedVisibleInCustomerGuide,
            PayeeId, ShareQuoteId, ItemId, ItemUnitId, TempQuoteId,
            OwnItemQuoteId, SharedItemQuoteId, ItemCode, ItemName,
            CategoryId, FullCategoryPath, CustomerLast3MAmount,
            Unit, RecentCost, P1, BaseMarkup, IsBaseToRecentCost,
            IsShareBasePrice, SharedBaseMarkup, BasePrice, BasePriceSource,
            BaseMarkupPrice, BaseMarkupSource,
            OwnMarkupPercent, OwnTargetPrice, OwnIsFixed,
            SharedMarkupPercent, SharedTargetPrice, SharedIsFixed,
            MarkupPercent, TargetPrice, IsFixed, FinalPrice, FinalPriceReason
        FROM SharedRows
    )
    SELECT
        RowKey, Source, IsEditable, IsSharedVisibleInCustomerGuide,
        PayeeId, ShareQuoteId, ItemId, ItemUnitId, TempQuoteId,
        OwnItemQuoteId, SharedItemQuoteId, ItemCode, ItemName,
        CategoryId, FullCategoryPath, CustomerLast3MAmount,
        Unit, RecentCost, P1, BaseMarkup, IsBaseToRecentCost,
        IsShareBasePrice, SharedBaseMarkup, BasePrice, BasePriceSource,
        BaseMarkupPrice, BaseMarkupSource,
        OwnMarkupPercent, OwnTargetPrice, OwnIsFixed,
        SharedMarkupPercent, SharedTargetPrice, SharedIsFixed,
        MarkupPercent, TargetPrice, IsFixed, FinalPrice, FinalPriceReason
    FROM AllRows
    ORDER BY ItemName, ItemUnitId;
END
GO
