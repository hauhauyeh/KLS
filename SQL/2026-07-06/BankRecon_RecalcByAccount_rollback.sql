-- Rollback for BankRecon_RecalcByAccount (bank-recon-auto-difference-v1) — drop the new proc.
-- Drop this only AFTER BankFeed_MatchTx / BankFeed_UnMatchTx have been rolled back to their baselines
-- (they call this proc).
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
DROP PROCEDURE IF EXISTS [dbo].[BankRecon_RecalcByAccount];
GO
