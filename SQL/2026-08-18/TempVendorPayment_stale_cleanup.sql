-- TempVendorPayment one-time stale-draft cleanup (2026-08-18)
--
-- Why: abandoned Vendor Payment sessions leave IsApplied=1 rows behind, and
-- BankFeed_CreateVendorPayment (THROW 50113) rightly refuses to create a payment
-- while such a draft exists for the (EmpId, PayeeId) pair - e.g. aditya blocked on
-- Palmdale Oil. The Angular modal now discards its drafts on close, but that fix
-- cannot reach debris created before it shipped. This script clears the backlog.
--
-- Safe to delete everything: TempVendorPayment is pure per-session scratch.
-- VendorPayment_Inject starts with DELETE ... WHERE EmpId AND PayeeId and reseeds
-- the full scope on every screen open; nothing references TempVPId afterwards.
--
-- Precondition: run while no one has a Vendor Payment screen mid-session
-- (off-hours). A user mid-session at run time would only need to reopen the
-- screen - no saved data is at risk.
--
-- No _rollback.sql: the rows are ephemeral scratch regenerated on demand;
-- there is no state to restore.
--
-- Deploy (after explicit approval only):
-- & "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe" -S "RAJNI\SQLEXPRESS" -d "KLS-2026" -C -b -i TempVendorPayment_stale_cleanup.sql

SET NOCOUNT ON;

SELECT COUNT(*) AS RowsBefore FROM dbo.TempVendorPayment;

DELETE FROM dbo.TempVendorPayment;

SELECT COUNT(*) AS RowsAfter FROM dbo.TempVendorPayment;
