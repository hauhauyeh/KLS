-- Data repair: Fix OrderDate and LastSyncAt timezone offset
-- Code was converting ShipStation dates as Pacific (UTC-7/UTC-8) but account is Eastern (UTC-4/UTC-5)
-- Pacific and Eastern are always 3 hours apart (both observe DST together)
-- So all stored UTC values are 3 hours ahead of correct
--
-- Run against: abc_2026

-- Preview: show sample of affected rows before fix
SELECT TOP 10 MarketOrderId, OrderDate AS [Before],
    DATEADD(HOUR, -3, OrderDate) AS [After]
FROM MarketOrder WHERE OrderDate IS NOT NULL
ORDER BY MarketOrderId;

-- Fix OrderDate: subtract 3 hours
UPDATE MarketOrder SET OrderDate = DATEADD(HOUR, -3, OrderDate)
WHERE OrderDate IS NOT NULL;

PRINT 'MarketOrder.OrderDate fixed: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';

-- Fix LastSyncAt watermark
UPDATE MarketAccount SET LastSyncAt = DATEADD(HOUR, -3, LastSyncAt)
WHERE MarketType = 'ShipStation' AND LastSyncAt IS NOT NULL;

PRINT 'MarketAccount.LastSyncAt fixed: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';
