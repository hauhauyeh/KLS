SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================================
-- Rollback for BankFeedSource_create.sql (2026-07-27).
-- Drops the indexes and then the table. Order is the reverse of the forward script.
-- Idempotent: safe to re-run.
--
-- Refuses to drop while rows exist. BankFeedSource is the only record of which
-- payments Bank Feed generated; dropping it with data present would strand those
-- payments with no way to tell them from manually created ones.
-- Deliberate: clear the rows yourself if you really mean to discard that history.
-- =============================================================================================

IF OBJECT_ID('dbo.BankFeedSource', 'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM dbo.BankFeedSource)
    THROW 50120, 'BankFeedSource still holds rows - generated payments would become untraceable. Clear it first if this is intended.', 1;
GO

IF EXISTS (SELECT 1 FROM sys.indexes
           WHERE name = 'UX_BankFeedSource_ActiveDoc'
             AND object_id = OBJECT_ID('dbo.BankFeedSource'))
    DROP INDEX UX_BankFeedSource_ActiveDoc ON dbo.BankFeedSource;
GO

IF EXISTS (SELECT 1 FROM sys.indexes
           WHERE name = 'IX_BankFeedSource_TxId'
             AND object_id = OBJECT_ID('dbo.BankFeedSource'))
    DROP INDEX IX_BankFeedSource_TxId ON dbo.BankFeedSource;
GO

IF EXISTS (SELECT 1 FROM sys.indexes
           WHERE name = 'IX_BankFeedSource_Doc'
             AND object_id = OBJECT_ID('dbo.BankFeedSource'))
    DROP INDEX IX_BankFeedSource_Doc ON dbo.BankFeedSource;
GO

IF EXISTS (SELECT 1 FROM sys.indexes
           WHERE name = 'IX_BankFeedSource_BankFeedTransactionId'
             AND object_id = OBJECT_ID('dbo.BankFeedSource'))
    DROP INDEX IX_BankFeedSource_BankFeedTransactionId ON dbo.BankFeedSource;
GO

IF OBJECT_ID('dbo.BankFeedSource', 'U') IS NOT NULL
    DROP TABLE dbo.BankFeedSource;
GO
