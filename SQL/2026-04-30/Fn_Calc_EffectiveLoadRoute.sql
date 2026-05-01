SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER FUNCTION [dbo].[Fn_Calc_EffectiveLoadRoute]
(
    @ShipRoute NVARCHAR(50),
    @RouteOrder INT,
    @IsLoadSeparate BIT
)
RETURNS NVARCHAR(50)
AS
BEGIN
    DECLARE @BaseRoute NVARCHAR(50) = NULLIF(LTRIM(RTRIM(@ShipRoute)), '');
    DECLARE @EffectiveLoadRoute NVARCHAR(50);

    SET @EffectiveLoadRoute =
        CASE
            WHEN @BaseRoute IS NULL THEN NULL
            WHEN ISNULL(@IsLoadSeparate, 0) = 1 AND @RouteOrder IS NOT NULL
                THEN @BaseRoute + CONVERT(VARCHAR(12), @RouteOrder)
            ELSE @BaseRoute
        END;

    RETURN @EffectiveLoadRoute;
END
GO
