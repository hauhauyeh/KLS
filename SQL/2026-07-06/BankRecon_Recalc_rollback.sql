-- Rollback for BankRecon_Recalc (bank-recon-auto-difference-v1) — drop the new proc.
-- NOTE: drop this only AFTER BankFeed_MatchTx / BankFeed_UnMatchTx have been rolled back to their
-- baselines, since RecalcByAccount (which those call) depends on this proc.
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
DROP PROCEDURE IF EXISTS [dbo].[BankRecon_Recalc];
GO
