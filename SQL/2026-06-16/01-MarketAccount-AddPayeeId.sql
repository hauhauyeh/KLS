-- Add PayeeId to MarketAccount for marketplace-to-sales conversion
-- Links each marketplace account to a KLS customer/payee (e.g., "ShipStation Sales")

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'MarketAccount' AND COLUMN_NAME = 'PayeeId'
)
BEGIN
    ALTER TABLE MarketAccount ADD PayeeId INT NULL
END
