-- DropShipment_DSCC_seed.sql
-- 2026-07-13: Idempotent seed for the drop-ship cost-clearing account @DSCC (DROP-SHIP COST CLEAR),
-- classified Asset/Inventory with IsAccountDebit=1. Companion to DropShipment_ConvertPOToBill (DSCC-FIX).
-- Deploy this BEFORE the SP. Re-runnable (single batch, no GO, so @InvCatId stays in scope).
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;

DECLARE @InvCatId INT;

-- Resolve the Inventory (Asset) category by a STABLE key, not a hardcoded id (category ids can differ per environment).
SELECT @InvCatId = AccountCategoryId
FROM dbo.AccountCategory
WHERE CategoryName = 'Inventory' AND ClassName = 'Asset';

IF @InvCatId IS NULL
    THROW 51002, 'Inventory (Asset) AccountCategory not found - cannot seed @DSCC.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.Account WHERE AccountCode = '@DSCC')
BEGIN
    INSERT INTO dbo.Account
        (AccountCategoryId, TypeName, SortOrder, IsAccountDebit, AccountCode, AccountName,
         AccountBalance, OpenBalance, Inactive, IsDefaultAccount, CreatedAt)
    VALUES
        (@InvCatId, 'Inventory', 0, 1, '@DSCC', 'DROP-SHIP COST CLEAR',
         0, 0, 0, 0, GETDATE());
END
ELSE
BEGIN
    -- Enforce the required configuration on an existing row (idempotent; only writes if something drifted).
    UPDATE dbo.Account
    SET AccountCategoryId = @InvCatId,
        IsAccountDebit    = 1,
        Inactive          = 0,
        UpdatedAt         = GETDATE()
    WHERE AccountCode = '@DSCC'
      AND (AccountCategoryId <> @InvCatId OR IsAccountDebit <> 1 OR ISNULL(Inactive, 0) <> 0);
END

-- Hard assertion (stable-key based). Fail loudly if @DSCC is missing or mis-configured.
IF NOT EXISTS (
    SELECT 1 FROM dbo.Account
    WHERE AccountCode = '@DSCC'
      AND AccountCategoryId = @InvCatId
      AND IsAccountDebit = 1
      AND ISNULL(Inactive, 0) = 0
)
    THROW 51000, '@DSCC missing/mis-configured (need Inventory/Asset, IsAccountDebit=1, active).', 1;

PRINT '@DSCC seed OK (Inventory/Asset, IsAccountDebit=1, active).';
