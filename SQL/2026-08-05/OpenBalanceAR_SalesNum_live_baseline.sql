-- 2026-08-05 live baseline for dbo.OpenBalanceAR, captured from KLS-2026 on
-- RAJNI\SQLEXPRESS before the SalesNum type change.
--
-- This file is the rollback reference for OpenBalanceAR_SalesNum_TypeChange.sql.

/*
Column definitions at capture time:

    OpenARId   int             NOT NULL  IDENTITY
    SalesId    int             NULL          <-- NULL on every row; the link has never been written
    SalesNum   int             NULL          <-- becomes NVARCHAR(50) NULL
    PayeeId    int             NOT NULL
    AsOfDate   date            NOT NULL
    Amount     decimal(18,2)   NOT NULL
    Notes      nvarchar(400)   NULL
    CreatedAt  datetime        NOT NULL

Indexes and constraints at capture time:

    PK_OpenBalanceAR  CLUSTERED UNIQUE on OpenARId
    Nothing indexes or constrains SalesNum, so ALTER COLUMN needs no drops.

Data at capture time:

    1618 rows
    1618 rows with a non-null SalesNum, values 1120248 - 1294766, longest 7 digits
    0    rows with a non-null SalesId

    Every SalesNum matches a real dbo.Sales row on SalesNumber + ShipId, so these are KLS
    sales numbers rather than client invoice numbers. The matched Sales rows all carry
    SalesDocNumber NULL and AmountDue 0.

    Because the longest value is 7 characters, every existing value converts into
    NVARCHAR(50) losslessly and converts back to int cleanly.
*/

-- Re-run this to confirm the baseline still holds before deploying:

SELECT
    c.name,
    t.name AS TypeName,
    c.max_length,
    c.is_nullable
FROM sys.columns c
JOIN sys.types t ON t.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID('dbo.OpenBalanceAR')
ORDER BY c.column_id;

SELECT
    COUNT(*)            AS RowCnt,
    COUNT(SalesNum)     AS SalesNumNotNull,
    COUNT(SalesId)      AS SalesIdNotNull
FROM dbo.OpenBalanceAR;
