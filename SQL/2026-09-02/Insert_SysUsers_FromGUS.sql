/* Insert_SysUsers_FromGUS.sql
   Creates the two support accounts SYSRajni and SYSHoward in the TARGET database
   by copying their Payee + Employee + SystemUser rows from GUS_2026 (same server).
   - Same password: PasswordHash is copied verbatim from GUS_2026 (AES blob, never shown).
   - PayeeIds 100012/100013 are taken by real employees in MGP-2026, so new PayeeIds
     are allocated as MAX+1 in the employee range (100000-109999). SystemUser login
     requires PayeeId to start with '1' and a matching Employee row.
   - Idempotent: a user whose Username already exists in the target is skipped.
   - HasOutsideAccess stays 0 (the IP allowlist check only applies when it is 1).

   HOW TO USE: set the USE line to the target DB (MGP-2026 now; ASA later), run whole script. */

USE [MGP-2026];
SET XACT_ABORT ON;
SET NOCOUNT ON;

DECLARE @Users TABLE (Seq INT IDENTITY(1,1), Username NVARCHAR(200));
INSERT INTO @Users (Username) VALUES (N'SYSRajni'), (N'SYSHoward');

DECLARE @Seq INT = 1, @MaxSeq INT;
SELECT @MaxSeq = MAX(Seq) FROM @Users;

BEGIN TRAN;

WHILE @Seq <= @MaxSeq
BEGIN
    -- Reset per iteration (stale vars would target the wrong row)
    DECLARE @Username NVARCHAR(200), @SrcPayeeId INT, @NewPayeeId INT;
    SELECT @Username = NULL, @SrcPayeeId = NULL, @NewPayeeId = NULL;

    SELECT @Username = Username FROM @Users WHERE Seq = @Seq;

    SELECT @SrcPayeeId = PayeeId
    FROM [GUS_2026].dbo.SystemUser
    WHERE Username = @Username;

    IF @SrcPayeeId IS NULL
    BEGIN
        ROLLBACK;
        RAISERROR('Source user not found in GUS_2026 - aborting.', 16, 1);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM dbo.SystemUser WHERE Username = @Username)
    BEGIN
        PRINT @Username + ' already exists in target - skipped.';
        SET @Seq += 1;
        CONTINUE;
    END

    -- Empty employee range (fresh tenant DB) starts at 100001
    SELECT @NewPayeeId = ISNULL(MAX(PayeeId), 100000) + 1
    FROM dbo.Payee
    WHERE PayeeId BETWEEN 100000 AND 109999;

    ---------------------------------------------------------------
    -- 1) Payee (system account, PayeeType 'E')
    ---------------------------------------------------------------
    INSERT INTO dbo.Payee
        (PayeeId, PayeeType, PayeeName, IsClosed, IsPastDue, IsCreditHold, IsDelinquent,
         IsSystemAccount, CreatedAt)
    SELECT
        @NewPayeeId, p.PayeeType, p.PayeeName, 0, 0, 0, 0,
        1, GETUTCDATE()
    FROM [GUS_2026].dbo.Payee p
    WHERE p.PayeeId = @SrcPayeeId;
    IF @@ROWCOUNT <> 1 BEGIN ROLLBACK; RAISERROR('Payee insert failed.', 16, 1); RETURN; END

    ---------------------------------------------------------------
    -- 2) Employee (required by admin login; HasOutsideAccess = 0)
    ---------------------------------------------------------------
    INSERT INTO dbo.Employee
        (PayeeId, FirstName, LastName,
         IsUsePayCheck, HasOutsideAccess, HasPastDueWarning, IsPriceChangeNotify, IsService)
    SELECT
        @NewPayeeId, e.FirstName, e.LastName,
        0, 0, 0, 0, 0
    FROM [GUS_2026].dbo.Employee e
    WHERE e.PayeeId = @SrcPayeeId;
    IF @@ROWCOUNT <> 1 BEGIN ROLLBACK; RAISERROR('Employee insert failed.', 16, 1); RETURN; END

    ---------------------------------------------------------------
    -- 3) SystemUser (Admin role, PasswordHash copied = same password)
    ---------------------------------------------------------------
    INSERT INTO dbo.SystemUser
        (SystemRoleId, PayeeId, Email, Username, PasswordHash, Inactive, CreatedAt)
    SELECT
        1, @NewPayeeId, su.Email, su.Username, su.PasswordHash, 0, GETUTCDATE()
    FROM [GUS_2026].dbo.SystemUser su
    WHERE su.PayeeId = @SrcPayeeId;
    IF @@ROWCOUNT <> 1 BEGIN ROLLBACK; RAISERROR('SystemUser insert failed.', 16, 1); RETURN; END

    PRINT @Username + ' created with PayeeId ' + CAST(@NewPayeeId AS VARCHAR(10));
    SET @Seq += 1;
END

COMMIT;

---------------------------------------------------------------
-- Verify
---------------------------------------------------------------
SELECT su.SystemUserId, su.SystemRoleId, su.PayeeId, su.Username, su.Inactive,
       p.PayeeName, p.IsSystemAccount, e.HasOutsideAccess
FROM dbo.SystemUser su
JOIN dbo.Payee p ON p.PayeeId = su.PayeeId
JOIN dbo.Employee e ON e.PayeeId = su.PayeeId
WHERE su.Username IN (N'SYSRajni', N'SYSHoward');
