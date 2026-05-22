-- Captured from live KLS_2026 on 2026-05-20 before refactor work.

-- =============================================
-- Author:      <Author,,Name>
-- Create date: <Create Date,,>
-- Description: <Description,,>
-- =============================================
CREATE PROCEDURE _exam_tx_inventory
    
AS
BEGIN
    -- SET NOCOUNT ON added to prevent extra result sets from
    -- interfering with SELECT statements.
    SET NOCOUNT ON;

    select t.TxId,t.TxDate,t.SourceDocType,t.SourceDocNumber,td.TxDetailId,td.AccountId,a.AccountName,td.Qty,td.Price,td.BillQty,td.FactorToBase,td.ClosingQty,td.AverageCost,td.InventoryValue,td.Amount,td.CrDeAmount,
    ROUND(td.ClosingQty*td.AverageCost,6) AS NewInvValue
    from TransactionJournal t inner join TransactionJournalDetail td on t.TxId=td.TxId
    join Account a on a.AccountId=td.AccountId
    where t.SourceDocNumber=1366617
    --where ItemId=1654 and AccountId=56 
    order by t.TxDate,t.SourceDocOrder,td.TxDetailId

    --declare @cloqty money
    --declare @avgcost money
    --declare @invvalue money
    --exec [RecalcQAV] 1654,'05/04/2026',@cloqty output,@avgcost output,@invvalue output
     
END
