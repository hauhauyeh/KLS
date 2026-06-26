SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Web_Customer_NextShipDate]
    @PayeeId   INT,
    @ShipDate  DATE OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @WebHour INT;

    SELECT @WebHour = TRY_CONVERT(INT, SettingValue)
    FROM SystemSetting
    WHERE SettingKey = 'WEB_ORDER_CHECKOUT_HOUR';

    EXEC dbo.Fn_Calc_NextShipDate @PayeeId, @ShipDate OUTPUT, @WebHour;
END
