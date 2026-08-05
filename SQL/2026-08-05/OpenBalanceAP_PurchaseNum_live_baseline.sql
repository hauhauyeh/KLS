-- 2026-08-05 live baseline for dbo.OpenBalanceAP, captured from KLS-2026 on RAJNI\SQLEXPRESS
-- before the PurchaseNum type change and adoption migration.
--
-- This file is the rollback reference. It records the state the
-- _rollback.sql script must restore.

/*
Column definitions at capture time:

    OpenAPId     int             NOT NULL  IDENTITY
    PurchaseId   int             NULL
    PurchaseNum  int             NULL          <-- becomes NVARCHAR(200) NULL
    PayeeId      int             NOT NULL
    AsOfDate     date            NOT NULL
    Amount       decimal(18,2)   NOT NULL
    Notes        nvarchar(400)   NULL
    CreatedAt    datetime        NOT NULL

Indexes and constraints at capture time:

    PK_OpenBalanceAP        CLUSTERED UNIQUE on OpenAPId
    FK_OpenBalanceAP_Payee  foreign key to dbo.Payee
    No index, check constraint or foreign key touches PurchaseNum,
    so ALTER COLUMN needs no drops.

Data at capture time:

    166 rows
    166 rows with a non-null PurchaseNum, values 77891 - 82006
    0   rows with a non-null PurchaseId

    All 166 PurchaseNum values match a real dbo.Purchase row on
    PurchaseNumber + PayeeId. Those purchases are StageId 6, header-only
    (0 PurchaseDetail rows), and all 166 carry VendorPaymentDetail rows.

    Simulated migration result: 160 rows take the matched
    Purchase.VendorDocNumber, 6 fall back to the old integer as text,
    29 of the 166 end up non-numeric, and no PayeeId+value pair repeats.
*/

-- Re-run this to confirm the baseline still holds before deploying:

SELECT
    c.name,
    t.name AS TypeName,
    c.max_length,
    c.is_nullable
FROM sys.columns c
JOIN sys.types t ON t.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID('dbo.OpenBalanceAP')
ORDER BY c.column_id;

SELECT
    COUNT(*)                AS RowCnt,
    COUNT(PurchaseNum)      AS PurchaseNumNotNull,
    COUNT(PurchaseId)       AS PurchaseIdNotNull
FROM dbo.OpenBalanceAP;
