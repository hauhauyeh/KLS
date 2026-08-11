-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[ItemQuote_Insert]
	
	@PayeeId int,
	@EmpId int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DELETE FROM ItemQuote WHERE PayeeId=@PayeeId

    INSERT INTO [dbo].[ItemQuote]
           ([PayeeId]
           ,[ItemId]
           ,[ItemUnitId]
           ,[MarkupPercent]
           ,[TargetPrice]
           ,[NewPrice]
           ,[OldPrice]
           ,[IsFixed]
           --,[Inactive]
           ,[CreatedAt])
     SELECT [PayeeId]
           ,[ItemId]
           ,[ItemUnitId]
           ,[MarkupPercent]
           ,[TargetPrice]
           ,[NewPrice]
           ,[OldPrice]
           ,[IsFixed]
           --,[Inactive]
           ,GETUTCDATE()
	FROM TempItemQuote WHERE PayeeId=@PayeeId AND EmpId=@EmpId

	DELETE FROM TempItemQuote WHERE PayeeId=@PayeeId AND EmpId=@EmpId
END

