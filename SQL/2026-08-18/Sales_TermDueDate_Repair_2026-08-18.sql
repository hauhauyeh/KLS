SET NOCOUNT ON;
SET XACT_ABORT ON;

/*
Repair early SO rows created while customers were temporarily COD.

Default is preview-only. To perform the local repair, change @PreviewOnly to 0.

Target database: local GUS_2026 only.
Approved row count: 12.
Approved SalesId list:
13, 14, 16, 28, 44, 48, 59, 61, 68, 83, 98, 106.
*/

DECLARE @PreviewOnly bit = 1;
DECLARE @ExpectedRows int = 12;
DECLARE @UpdatedRows int = 0;

IF DB_NAME() <> N'GUS_2026'
    THROW 51000, 'Wrong database. This repair is approved only for local GUS_2026.', 1;

IF COL_LENGTH('dbo.Term', 'Inactive') IS NULL
    THROW 51001, 'Expected column dbo.Term.Inactive was not found.', 1;

IF OBJECT_ID('dbo.SalesStage', 'U') IS NULL
    THROW 51002, 'Expected table dbo.SalesStage was not found.', 1;

IF OBJECT_ID('dbo.Payee_UpdateAging', 'P') IS NULL
    THROW 51003, 'Expected procedure dbo.Payee_UpdateAging was not found.', 1;

CREATE TABLE #ApprovedSales
(
    SalesId int NOT NULL PRIMARY KEY
);

INSERT INTO #ApprovedSales (SalesId)
VALUES
    (13),
    (14),
    (16),
    (28),
    (44),
    (48),
    (59),
    (61),
    (68),
    (83),
    (98),
    (106);

CREATE TABLE #Candidate
(
    SalesId int NOT NULL PRIMARY KEY,
    SalesNumber int NOT NULL,
    DocType char(2) NULL,
    StageId int NULL,
    StageName nvarchar(100) NULL,
    CustomerId int NOT NULL,
    CustomerName nvarchar(255) NULL,
    OldTermId int NULL,
    OldTermName nvarchar(50) NULL,
    OldTermGroup nvarchar(50) NULL,
    TargetTermId int NOT NULL,
    TargetTermName nvarchar(50) NOT NULL,
    TargetTermType nvarchar(50) NULL,
    TargetTermGroup nvarchar(50) NULL,
    TargetDueDays int NOT NULL,
    ShipDate date NOT NULL,
    OldDueDate date NOT NULL,
    ProposedDueDate date NOT NULL,
    AmountDue decimal(18, 2) NULL
);

INSERT INTO #Candidate
(
    SalesId,
    SalesNumber,
    DocType,
    StageId,
    StageName,
    CustomerId,
    CustomerName,
    OldTermId,
    OldTermName,
    OldTermGroup,
    TargetTermId,
    TargetTermName,
    TargetTermType,
    TargetTermGroup,
    TargetDueDays,
    ShipDate,
    OldDueDate,
    ProposedDueDate,
    AmountDue
)
SELECT
    s.SalesId,
    s.SalesNumber,
    s.DocType,
    s.StageId,
    ss.StageName,
    p.PayeeId AS CustomerId,
    p.PayeeName AS CustomerName,
    s.TermId AS OldTermId,
    oldt.TermName AS OldTermName,
    oldt.TermGroup AS OldTermGroup,
    p.TermId AS TargetTermId,
    newt.TermName AS TargetTermName,
    newt.TermType AS TargetTermType,
    newt.TermGroup AS TargetTermGroup,
    newt.DueDays AS TargetDueDays,
    s.ShipDate,
    s.DueDate AS OldDueDate,
    DATEADD(day, newt.DueDays, s.ShipDate) AS ProposedDueDate,
    s.AmountDue
FROM dbo.Sales AS s
INNER JOIN #ApprovedSales AS a ON a.SalesId = s.SalesId
INNER JOIN dbo.Payee AS p ON p.PayeeId = s.ShipId
INNER JOIN dbo.Term AS oldt ON oldt.TermId = s.TermId
INNER JOIN dbo.Term AS newt ON newt.TermId = p.TermId
LEFT JOIN dbo.SalesStage AS ss ON ss.StageId = s.StageId
WHERE ISNULL(s.AmountDue, 0) <> 0
  AND s.DocType = 'SO'
  AND s.StageId IN (3, 4)
  AND oldt.TermGroup = 'COD'
  AND ISNULL(newt.TermGroup, '') <> 'COD'
  AND newt.TermType = 'FixDays'
  AND newt.Inactive = 0
  AND s.ShipDate IS NOT NULL
  AND s.DueDate IS NOT NULL
  AND s.DueDate = s.ShipDate
  AND newt.DueDays IS NOT NULL;

SELECT
    'Approved candidate preview' AS ResultSet,
    SalesId,
    SalesNumber,
    DocType,
    StageName,
    CustomerId,
    CustomerName,
    OldTermName,
    TargetTermName,
    ShipDate,
    OldDueDate,
    ProposedDueDate,
    AmountDue
FROM #Candidate
ORDER BY CustomerId, SalesNumber;

IF (SELECT COUNT(*) FROM #ApprovedSales) <> @ExpectedRows
    THROW 51004, 'Approved SalesId list does not match expected row count.', 1;

IF (SELECT COUNT(*) FROM #Candidate) <> @ExpectedRows
    THROW 51005, 'Approved rows no longer match the repair criteria. Stop and re-audit.', 1;

IF EXISTS
(
    SELECT 1
    FROM #ApprovedSales AS a
    LEFT JOIN #Candidate AS c ON c.SalesId = a.SalesId
    WHERE c.SalesId IS NULL
)
    THROW 51006, 'At least one approved SalesId is missing from the safe candidate set.', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.Sales AS s
    INNER JOIN dbo.Payee AS p ON p.PayeeId = s.ShipId
    INNER JOIN dbo.Term AS oldt ON oldt.TermId = s.TermId
    INNER JOIN dbo.Term AS newt ON newt.TermId = p.TermId
    WHERE ISNULL(s.AmountDue, 0) <> 0
      AND s.DocType = 'SO'
      AND s.StageId IN (3, 4)
      AND oldt.TermGroup = 'COD'
      AND ISNULL(newt.TermGroup, '') <> 'COD'
      AND newt.TermType = 'FixDays'
      AND newt.Inactive = 0
      AND s.ShipDate IS NOT NULL
      AND s.DueDate IS NOT NULL
      AND s.DueDate = s.ShipDate
      AND newt.DueDays IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM #ApprovedSales AS a WHERE a.SalesId = s.SalesId)
)
    THROW 51007, 'Extra matching SO row exists outside the approved SalesId list. Stop and re-audit.', 1;

SELECT
    'Before aging' AS ResultSet,
    p.PayeeId AS CustomerId,
    p.PayeeName AS CustomerName,
    p.PayeeCurrent,
    p.Payee30,
    p.Payee60,
    p.Payee90,
    p.PayeeOver90,
    p.PayeeTotalDue,
    p.FirstDueDate
FROM dbo.Payee AS p
WHERE EXISTS (SELECT 1 FROM #Candidate AS c WHERE c.CustomerId = p.PayeeId)
ORDER BY p.PayeeId;

IF @PreviewOnly = 1
BEGIN
    SELECT
        'PREVIEW ONLY - no Sales rows were updated. Set @PreviewOnly = 0 for Slice 4 local repair.' AS Message,
        @ExpectedRows AS ExpectedRows,
        (SELECT COUNT(*) FROM #Candidate) AS SafeCandidateRows;
    RETURN;
END;

BEGIN TRANSACTION;

UPDATE s
SET
    s.TermId = c.TargetTermId,
    s.DueDate = c.ProposedDueDate
FROM dbo.Sales AS s
INNER JOIN #Candidate AS c ON c.SalesId = s.SalesId;

SET @UpdatedRows = @@ROWCOUNT;

IF @UpdatedRows <> @ExpectedRows
    THROW 51008, 'Updated row count does not match expected row count.', 1;

DECLARE @CustomerId int;

DECLARE affected_customer_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT DISTINCT CustomerId
    FROM #Candidate
    ORDER BY CustomerId;

OPEN affected_customer_cursor;
FETCH NEXT FROM affected_customer_cursor INTO @CustomerId;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC dbo.Payee_UpdateAging @PayeeId = @CustomerId, @IsSales = 1;
    FETCH NEXT FROM affected_customer_cursor INTO @CustomerId;
END;

CLOSE affected_customer_cursor;
DEALLOCATE affected_customer_cursor;

COMMIT TRANSACTION;

SELECT
    'Updated sales' AS ResultSet,
    s.SalesId,
    s.SalesNumber,
    s.ShipId AS CustomerId,
    s.TermId AS NewSalesTermId,
    t.TermName AS NewSalesTermName,
    s.ShipDate,
    s.DueDate,
    s.AmountDue
FROM dbo.Sales AS s
INNER JOIN #Candidate AS c ON c.SalesId = s.SalesId
INNER JOIN dbo.Term AS t ON t.TermId = s.TermId
ORDER BY s.ShipId, s.SalesNumber;

SELECT
    'After aging' AS ResultSet,
    p.PayeeId AS CustomerId,
    p.PayeeName AS CustomerName,
    p.PayeeCurrent,
    p.Payee30,
    p.Payee60,
    p.Payee90,
    p.PayeeOver90,
    p.PayeeTotalDue,
    p.FirstDueDate
FROM dbo.Payee AS p
WHERE EXISTS (SELECT 1 FROM #Candidate AS c WHERE c.CustomerId = p.PayeeId)
ORDER BY p.PayeeId;
