-- Add TimeZone column to MarketAccount for dynamic timezone per account
-- Previously hardcoded to Pacific in ShipStationApiClient; now read from this column

ALTER TABLE MarketAccount ADD TimeZone NVARCHAR(50) NULL;

-- Set existing ShipStation account to Eastern (confirmed from ShipStation account settings)
UPDATE MarketAccount SET TimeZone = 'Eastern Standard Time' WHERE MarketType = 'ShipStation';
