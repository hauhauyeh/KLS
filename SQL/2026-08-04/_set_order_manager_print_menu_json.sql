-- Set GUS Order Manager document/print menu JSON.
-- This script is intentionally guarded for GUS_2026 only.
--
-- Full readable JSON version:
-- {
--   "singleOrder": {
--     "GenInvoice": {
--       "label": "Gen Invoice/CM",
--       "visible": true
--     },
--     "EmailInvoice": {
--       "label": "Email Invoice",
--       "visible": true,
--       "stageIdAfterSuccess": 3
--     },
--     "GenSalesOrder": {
--       "label": "Gen Sales Order/CM",
--       "visible": true
--     },
--     "GenPickTicket": {
--       "label": "Gen Packing Slip",
--       "visible": true,
--       "stageIdAfterSuccess": 2
--     }
--   }
-- }
--
-- Missing batch group means the footer Print button is hidden.

IF DB_NAME() <> 'GUS_2026'
BEGIN
    THROW 51000, 'This script is only intended for database GUS_2026.', 1;
END;

DECLARE @SettingKey NVARCHAR(200) = N'SALES_ORDER_DOCUMENT_MENU_JSON';
DECLARE @Json NVARCHAR(MAX) = N'{
  "singleOrder": {
    "GenInvoice": {
      "label": "Gen Invoice/CM",
      "visible": true
    },
    "EmailInvoice": {
      "label": "Email Invoice",
      "visible": true,
      "stageIdAfterSuccess": 3
    },
    "GenSalesOrder": {
      "label": "Gen Sales Order/CM",
      "visible": true
    },
    "GenPickTicket": {
      "label": "Gen Packing Slip",
      "visible": true,
      "stageIdAfterSuccess": 2
    }
  }
}';

IF ISJSON(@Json) <> 1
BEGIN
    THROW 51001, 'Invalid SALES_ORDER_DOCUMENT_MENU_JSON.', 1;
END;

DECLARE @CompanyTimeZone NVARCHAR(100);

SELECT TOP (1) @CompanyTimeZone = TimeZone
FROM dbo.Company;

SET @CompanyTimeZone = ISNULL(NULLIF(LTRIM(RTRIM(@CompanyTimeZone)), ''), 'Eastern Standard Time');

DECLARE @CompanyNow DATETIME =
    CAST(SYSUTCDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE @CompanyTimeZone AS DATETIME);

UPDATE dbo.SystemSetting
SET SettingValue = @Json,
    DataType = 'json',
    Description = 'Order Manager document/print menu configuration.',
    UpdatedAt = @CompanyNow
WHERE SettingKey = @SettingKey;

IF @@ROWCOUNT = 0
BEGIN
    INSERT INTO dbo.SystemSetting
    (
        SettingKey,
        SettingValue,
        DataType,
        Description,
        CreatedAt
    )
    VALUES
    (
        @SettingKey,
        @Json,
        'json',
        'Order Manager document/print menu configuration.',
        @CompanyNow
    );
END;

SELECT
    SettingKey,
    DataType,
    IsValidJson = ISJSON(SettingValue),
    SettingValue
FROM dbo.SystemSetting
WHERE SettingKey = @SettingKey;
