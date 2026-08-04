SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- Permission rows for the Opening Balance screen.
-- 2026-08-04: NEW.
--
-- ACCOUNTING module, not Admin. The Admin menu is system configuration
-- (roles, terms, trucks, tags, holidays, email logs); Opening Balance
-- writes GeneralJournal / TransactionJournal / TransactionJournalDetail
-- and its five journals show up in the General Journals list beside it.
--
-- Shape copied from the neighbouring Accounting.GeneralJournal rows:
--   1000  Accounting                      menu      parent NULL
--   1200  Accounting.GeneralJournal       resource  parent 1000
--   1201  Accounting.GeneralJournal.List  page      parent 1200
--   1202  Accounting.GeneralJournal.Save  button    parent 1200
--
-- Two things that are easy to get wrong and are NOT what a summary of the
-- convention would suggest:
--   * [Action] is NOT NULL. Menu and resource rows use '' , not NULL.
--   * BUTTON rows parent to the RESOURCE row (1450), not to the page row.
--
-- Accounting allocates in blocks of 50 (1050 Account .. 1400 BankFeed).
-- 1450-1460 were free when this was written -- re-check before running.
--
-- Three keys, not four: Save and Post are one action ("Save & Import"),
-- so there is no separate .Post permission to grant.
-- ============================================================

SET IDENTITY_INSERT dbo.Permission ON;
GO

INSERT INTO dbo.Permission
    (PermissionId, PermissionKey, DisplayName, Module, Resource, [Action],
     PermissionType, ParentPermissionId, SortOrder, IsActive)
VALUES
    (1450, 'Accounting.OpeningBalance', 'Opening Balance',
     'Accounting', 'OpeningBalance', '',
     'resource', 1000, 1450, 1),

    (1451, 'Accounting.OpeningBalance.List', 'Opening Balance',
     'Accounting', 'OpeningBalance', 'List',
     'page', 1450, 1451, 1),

    (1452, 'Accounting.OpeningBalance.Import', 'Import Opening Balance',
     'Accounting', 'OpeningBalance', 'Import',
     'button', 1450, 1452, 1),

    (1453, 'Accounting.OpeningBalance.Unpost', 'Unpost Opening Balance',
     'Accounting', 'OpeningBalance', 'Unpost',
     'button', 1450, 1453, 1);
GO

SET IDENTITY_INSERT dbo.Permission OFF;
GO

-- CreatedAt is left to its DEFAULT (getutcdate()), like every other
-- CreatedAt in this schema.

-- Verify
-- SELECT PermissionId, PermissionKey, PermissionType, [Action], ParentPermissionId, SortOrder
-- FROM dbo.Permission WHERE PermissionId BETWEEN 1450 AND 1460 ORDER BY PermissionId;
