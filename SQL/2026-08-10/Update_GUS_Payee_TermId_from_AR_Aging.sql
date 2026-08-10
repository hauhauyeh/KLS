-- Update GUS_2026.dbo.Payee.TermId from "GUS-AR Agubg Detail 07.31.2026.xlsx" (Name -> Terms)
-- Source: 23 customers in the AR aging report carry a Terms value; all matched Payee by name.
-- Excel term -> TermId mapping: COD -> 2 (COD), Net 15 -> 17 (NET15), Net 30 -> 24 (NET30).
-- Approved by Rajni 2026-08-10: Net 20 -> NET21 (23), Net 10 -> NET14 (16).
USE GUS_2026;
GO

SET XACT_ABORT ON;
BEGIN TRAN;

;WITH Map AS (
    SELECT * FROM (VALUES
        -- COD (TermId 2) — already the current value for all rows; kept for idempotency
        ('BESTONE TRADING INC',             2),
        ('ECO SANITARY SUPLIES, INC.',      2),
        ('ENZO SUPPLIES INC',               2),
        ('Eagle Avenue, Inc.',              2),
        ('FIRST PACKAGING SYSTEMS',         2),
        ('Henrez Industries LLC',           2),
        ('J & Y S,INC',                     2),
        ('Megatech Global, Inc.',           2),
        ('SUPER SECURE PACKAGING SUPPLIES', 2),
        ('UNIPACK TRADING INC',             2),
        ('WELLCARE INTERNATIONAL CA INC',   2),
        -- Net 15 (TermId 17 = NET15)
        ('CaseStore LLC',                   17),
        ('SAFETY GROUP LLC',                17),
        ('VERTEX PACKAGING SUPPLIES',       17),
        -- Net 30 (TermId 24 = NET30)
        ('8 NET INC',                       24),
        ('ENS PACKAGING SOLUTION',          24),
        ('Greenway Worldwide LLC',          24),
        ('JDL Packaging Systems, Inc.',     24),
        ('JPACK INT''L INC.',               24),
        ('PRECOCITY,LLC',                   24),
        ('SCIENTEX PHOENIX,LLC',            24),
        -- Net 20 (TermId 23 = NET21, approved closest match)
        ('B & C INDUSTRIES',                23),
        -- Net 10 (TermId 16 = NET14, approved closest match)
        ('RELIANCE PACKAGING,INC',          16)
    ) v(PayeeName, TermId)
)
UPDATE p
SET p.TermId = m.TermId
FROM dbo.Payee p
JOIN Map m ON m.PayeeName = p.PayeeName
WHERE ISNULL(p.TermId, 0) <> m.TermId;

PRINT CONCAT('Rows updated: ', @@ROWCOUNT);  -- expected: 12 (COD rows are no-ops)

COMMIT;
GO

-- Verify
SELECT p.PayeeId, p.PayeeName, p.TermId, t.TermName
FROM dbo.Payee p
LEFT JOIN dbo.Term t ON t.TermId = p.TermId
WHERE p.PayeeName IN (
    '8 NET INC','B & C INDUSTRIES','BESTONE TRADING INC','CaseStore LLC',
    'ECO SANITARY SUPLIES, INC.','ENS PACKAGING SOLUTION','ENZO SUPPLIES INC',
    'Eagle Avenue, Inc.','FIRST PACKAGING SYSTEMS','Greenway Worldwide LLC',
    'Henrez Industries LLC','J & Y S,INC','JDL Packaging Systems, Inc.',
    'JPACK INT''L INC.','Megatech Global, Inc.','PRECOCITY,LLC',
    'RELIANCE PACKAGING,INC','SAFETY GROUP LLC','SCIENTEX PHOENIX,LLC',
    'SUPER SECURE PACKAGING SUPPLIES','UNIPACK TRADING INC',
    'VERTEX PACKAGING SUPPLIES','WELLCARE INTERNATIONAL CA INC'
)
ORDER BY p.PayeeName;
GO
