-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[ItemQuote_Inject]

	@PayeeId int,
	@EmpId int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DELETE FROM TempItemQuote WHERE EmpId=@EmpId

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
