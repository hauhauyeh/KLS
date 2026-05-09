CREATE PROCEDURE [dbo].[Report_StoreTotal] --[Report_StoreTotal] '01/02/2026'
	
	@ShipDate DATE
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT sd.SalesDetailId As Id,
	st.Section,
	CASE WHEN sd.Notes IS NOT NULL THEN i.ItemName+' ('+sd.Notes+')' ELSE i.ItemName END AS ItemName,
	sd.ShipQty,
	sd.Unit,
	s.ShipDate
	FROM Sales AS s INNER JOIN SalesDetail AS sd ON s.SalesId=sd.SalesId
	INNER JOIN Item AS i ON sd.ItemId=i.ItemId
	LEFT JOIN ItemStorage as st on st.StorageId=i.StorageId 
	WHERE s.ShipDate=@ShipDate AND sd.ShipQty>0 
	AND st.Zone='Cooler' AND sd.Unit!='cs'
	ORDER BY st.SortOrder,i.ItemName

END
