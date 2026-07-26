-- ItemQuoteManager_GetList absence baseline for ItemQuote Manager Phase 4B.
-- Captured from local KLS_2026 on 2026-07-25 before creating the read-only manager list SP.

SELECT COUNT(*) AS ExistingObjectCount
FROM sys.objects
WHERE name = 'ItemQuoteManager_GetList';

-- Expected before Phase 4B deploy:
-- ExistingObjectCount = 0
