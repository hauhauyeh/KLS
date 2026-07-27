SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[ItemQuote_Inject] -- EXEC dbo.ItemQuote_Inject @PayeeId = 302017, @EmpId = 100050

	@PayeeId int,
	@EmpId int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- 2026-07-25 4C-1: keep other customer quote drafts for the same employee.
	-- Old behavior:
	-- DELETE FROM TempItemQuote WHERE EmpId=@EmpId
	DELETE FROM TempItemQuote
	WHERE EmpId=@EmpId
	  AND PayeeId=@PayeeId

	INSERT INTO [dbo].[TempItemQuote]
           ([EmpId]
           ,[PayeeId]
           ,[ItemId]
           ,[ItemUnitId]
           ,[MarkupPercent]
           ,[TargetPrice]
           ,[NewPrice]
           ,[OldPrice]
           ,[IsFixed])
     SELECT @EmpId
           ,[PayeeId]
           ,[ItemId]
           ,[ItemUnitId]
           ,[MarkupPercent]
           ,[TargetPrice]
           ,[NewPrice]
           ,[OldPrice]
           ,[IsFixed]
     FROM ItemQuote WHERE PayeeId=@PayeeId
END
GO
