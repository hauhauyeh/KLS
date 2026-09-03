-- Set Order Manager document/print menu JSON for MGP.
-- This script is intentionally guarded by Company.CompanyCode = MGP.
--
-- Rendered menu:
-- Single order:
--   Invoice
--   Pick Ticket
--   Packing List
-- Footer route print:
--   Invoice by Route
--   Pick Ticket by Route
--   Packing List by Route

DECLARE @CompanyCode NVARCHAR(20);

SELECT TOP (1) @CompanyCode = CompanyCode
FROM dbo.Company;

IF ISNULL(UPPER(LTRIM(RTRIM(@CompanyCode))), '') <> 'MGP'
BEGIN
    THROW 51000, 'This script is only intended for MGP company databases.', 1;
END;

DECLARE @SettingKey NVARCHAR(200) = N'SALES_ORDER_DOCUMENT_MENU_JSON';
DECLARE @Json NVARCHAR(MAX) = N'{
  "singleOrder": {
    "PrintInvoice": {
      "label": "Invoice",
      "visible": true,
      "stageIdAfterSuccess": 3
    },
    "PrintPickTicket": {
      "label": "Pick Ticket",
      "visible": true,
      "stageIdAfterSuccess": 2
    },
    "PrintPackingList": {
      "label": "Packing List",
      "visible": true
    }
  },
  "batch": {
    "PrintInvoiceByRoute": {
      "label": "Invoice",
      "visible": true,
      "stageIdAfterSuccess": 3
    },
    "PrintPickTicketByRoute": {
      "label": "Pick Ticket",
      "visible": true,
      "stageIdAfterSuccess": 2
    },
    "PrintPackingListByRoute": {
      "label": "Packing List",
      "visible": true
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
