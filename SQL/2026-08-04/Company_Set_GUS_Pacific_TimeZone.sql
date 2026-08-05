-- Set hosted GUS company business timezone to Pacific time.
-- SQL Server Windows timezone IDs handle daylight saving through AT TIME ZONE.

IF DB_NAME() <> 'GUS_2026'
BEGIN
    THROW 51000, 'This script is only intended for database GUS_2026.', 1;
END;

UPDATE dbo.Company
SET TimeZone = 'Pacific Standard Time'
WHERE CompanyId = 1;

SELECT CompanyId, CompanyName, TimeZone
FROM dbo.Company
WHERE CompanyId = 1;
