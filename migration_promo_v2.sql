-- Promotion Evaluation Engine v2: Add PromoPrice to PromotionBogo
-- Run this against KLS_Latest database

-- Add PromoPrice column to PromotionBogo table
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('PromotionBogo') AND name = 'PromoPrice')
BEGIN
    ALTER TABLE PromotionBogo ADD PromoPrice DECIMAL(18,2) NULL;
END

-- Ensure HasOwnList column exists on Payee table (used by Fn_GetPrice, now mapped in C# model)
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Payee') AND name = 'HasOwnList')
BEGIN
    ALTER TABLE Payee ADD HasOwnList BIT NOT NULL DEFAULT 0;
END
