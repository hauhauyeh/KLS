USE [KLS-2026]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- VendorPayment_ImportPreview
-- 2026-07-10: NEW. Read-only companion to VendorPayment_Import.
--   Parses the uploaded PayNow workbook and returns one row per
--   Excel row, enriched with the database values the importer will
--   actually use, so the user can verify the transactions before any
--   money is posted.
--
-- Why a stored procedure and not ClosedXML in .NET: the import parse
--   is done by SQL Server via the ACE OLEDB provider. Previewing in
--   .NET and importing via OPENROWSET would let the two disagree --
--   most dangerously on ACE's type sniffing, which infers a column's
--   type from the first 8 rows, so a PmtAmount column whose leading
--   rows look like text silently yields NULL. This proc runs the
--   IDENTICAL OPENROWSET statement against the IDENTICAL table-variable
--   shape, so what the user sees is what the importer will read.
--
-- The ONE deliberate deviation: [Batch] is INT NULL here, INT NOT NULL
--   in the importer. A blank batch cell makes the importer's
--   INSERT ... EXEC die with "Msg 515: Cannot insert the value NULL
--   into column 'Batch'" -- a raw error naming no row, which is exactly
--   the failure this preview exists to explain. Relaxing nullability is
--   safe because nullability is not part of the parse: ACE decides each
--   column's shape and type from the workbook alone, before SQL Server
--   sees a row; the target column's constraint only governs whether the
--   already-parsed value is accepted. Every other column of the
--   importer's table variable is already nullable.
--
-- Writes nothing. No TempPurchase staging, no VendorPayment rows.
-- ============================================================

CREATE OR ALTER PROCEDURE [dbo].[VendorPayment_ImportPreview]

	@FilePath NVARCHAR(255)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Qry NVARCHAR(MAX)

	-- Identical shape to VendorPayment_Import's @PayNowExcel, except [Batch] INT NULL.
	DECLARE @PayNowExcel AS TABLE (
		[AutoId] INT IDENTITY(1,1),
		[EnterDate] DATE NULL,
		[ArrivalDate] DATE NULL,
		[PayeeId] INT NULL,
		[PayeeName] nvarchar(255) NULL,
		[PmtRefNum] nvarchar(255) NULL,
		[AccountCode] nvarchar(50) NULL,
		[AccountName] nvarchar(255) NULL,
		[PmtAmount] DECIMAL(18,2) NULL,
		[Note] nvarchar(255) NULL,
		[BankDate] DATE NULL,
		[Batch] INT NULL
	)

	BEGIN TRY

		-- Identical to VendorPayment_Import.
		SET @Qry='SELECT * FROM OPENROWSET(''Microsoft.ACE.OLEDB.12.0'',
    ''Excel 12.0; HDR=yes; Database='+CONVERT(NVARCHAR(255),@FilePath)+''', [Sheet1$]);'

		INSERT INTO @PayNowExcel
		EXEC (@Qry)

	END TRY
	BEGIN CATCH

		-- Lead with the actionable cause, but keep the underlying ACE/provider
		-- error appended -- "file not found", "provider not registered" and
		-- "sheet not found" are different problems and must stay tellable apart.
		DECLARE @ErrMsg NVARCHAR(2048) =
			'Unable to read the Excel file. Check that it has a Sheet1 tab with the expected header row. Details: '
			+ ERROR_MESSAGE();

		THROW 51000, @ErrMsg, 1;

	END CATCH;

	-- Batch aggregates must be GROUPed, not windowed: SQL Server rejects
	-- COUNT(DISTINCT ...) OVER (...) with "Msg 10759: Use of DISTINCT is not
	-- allowed with the OVER clause."
	;WITH Batches AS (
		SELECT	[Batch],
				BatchRowCount	= COUNT(*),
				BatchTotal		= SUM([PmtAmount]),
				BatchPayeeCount	= COUNT(DISTINCT [PayeeId]),
				BatchPayeeId	= MIN([PayeeId]),		-- the payee the importer's TOP(1) lands on
				BatchRefNum		= MIN([PmtRefNum])
		FROM @PayNowExcel
		GROUP BY [Batch]
	)
	SELECT	RowNo				= p.[AutoId],
			p.[EnterDate],
			p.[ArrivalDate],
			p.[PayeeId],
			p.[PayeeName],
			p.[PmtRefNum],
			p.[AccountCode],
			p.[AccountName],
			p.[PmtAmount],
			p.[Note],
			p.[BankDate],
			p.[Batch],
			DbPayeeName			= py.[PayeeName],
			DbAccountId			= acct.[AccountId],
			DbAccountName		= acct.[AccountName],
			AccountMatchCount	= ISNULL(am.[MatchCount], 0),
			b.[BatchRowCount],
			b.[BatchTotal],
			b.[BatchPayeeCount],
			IsDuplicate			= CASE WHEN EXISTS (
										SELECT 1
										FROM [VendorPayment] vp
										WHERE vp.[PayeeId] = b.[BatchPayeeId]
										  AND vp.[ReferenceId] = b.[BatchRefNum]
										  AND vp.[PaymentAmount] = b.[BatchTotal])
									THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END
	FROM @PayNowExcel p
	-- NULL-safe join: a blank Batch cell groups with the other blanks.
	LEFT JOIN Batches b
		   ON b.[Batch] = p.[Batch]
		   OR (b.[Batch] IS NULL AND p.[Batch] IS NULL)
	-- Primary-key join: cannot multiply rows.
	LEFT JOIN [Payee] py
		   ON py.[PayeeId] = p.[PayeeId]
	-- A plain LEFT JOIN Account ON AccountCode would DUPLICATE the preview row
	-- whenever a code matches two accounts -- exactly the ambiguity we are trying
	-- to surface -- silently inflating BatchTotal, BatchRowCount and the line list.
	-- OUTER APPLY TOP 1 picks the representative account the importer's scalar
	-- subquery would target; the pre-aggregated MatchCount detects the ambiguity.
	OUTER APPLY (
		SELECT TOP 1 a.[AccountId], a.[AccountName]
		FROM [Account] a
		WHERE a.[AccountCode] = p.[AccountCode]
		ORDER BY a.[AccountId]
	) acct
	LEFT JOIN (
		SELECT [AccountCode], MatchCount = COUNT(*)
		FROM [Account]
		GROUP BY [AccountCode]
	) am
		   ON am.[AccountCode] = p.[AccountCode]
	ORDER BY p.[Batch], p.[AutoId];
END
GO
