CREATE TRIGGER [dbo].[TRG_Delete_HasOwnList]
   ON  [dbo].[ItemQuote] 
   AFTER INSERT,DELETE
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	 /* INSERT: any PayeeId inserted must have HasOwnList = 1 */
	UPDATE c
        SET c.HasOwnList = 1
    FROM dbo.Customer c
    INNER JOIN (
        SELECT DISTINCT PayeeId FROM inserted
    ) i ON i.PayeeId = c.PayeeId;


	/* DELETE: set HasOwnList based on remaining ItemQuote rows */
	UPDATE c
    SET c.HasOwnList =
        CASE WHEN EXISTS (
            SELECT 1
            FROM dbo.ItemQuote iq
            WHERE iq.PayeeId = c.PayeeId
        )
        THEN 1 ELSE 0 END
    FROM dbo.Customer c
    INNER JOIN (SELECT DISTINCT PayeeId FROM deleted) d
        ON d.PayeeId = c.PayeeId;
	
END
