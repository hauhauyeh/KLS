# Customer Payment v3 - Database Deployment Guide

## Overview

This deployment reworks the TempCustomerPayment cart to support unified allocation for:

- invoices
- credit memos
- unapplied payments
- debit memos
- CC fees

It also finalizes the stable committed funding-source link:

- use `SourcePaymentNumber`
- do not use `SourceCustomerPaymentId`

`CustomerPaymentId` changes when a payment is edited/recreated. `PaymentNumber` is the stable business key.

## Final Script Set

Run these scripts only.

1. `KLS/SQL/TempCustomerPayment_SchemaRework_v3.sql`
2. `KLS/SQL/CustomerPaymentDetail_AddSourcePaymentNumber.sql`
3. `KLS/SQL/CustomerPaymentSourceUse_Create.sql`
4. `KLS/SQL/CustomerPayment_Inject_v3.sql`
5. `KLS/SQL/TempCustomerPayment_GetList_v3.sql`
6. `KLS/SQL/TempCustomerPayment_InsertInvoice_v3.sql`
7. `KLS/SQL/CustomerPayment_Insert_v3.sql`
8. `KLS/SQL/CustomerPayment_InsertCCFee_v3.sql`
9. `KLS/SQL/CustomerPayment_Delete_v3.sql`
10. `KLS/SQL/TRG_Delete_CustomerPaymentTx_v3.sql`
11. `KLS/SQL/Report_CustomerPayment.sql` (optional)
12. `KLS/SQL/CustomerPayment_RecalcHeaderAmounts_v3.sql` (post-deploy repair / maintenance)

Rollback helpers:

- `KLS/SQL/CustomerPaymentSourceUse_Create_rollback.sql`
- `KLS/SQL/CustomerPayment_Delete_v3_rollback.sql`
- `KLS/SQL/TRG_Delete_CustomerPaymentTx_v3_rollback.sql`

## Execution Order

Run scripts in this order against `KLS_Latest` on `COGENT-2024\SQLEXPRESS`.

### Step 1: Temp Schema

`TempCustomerPayment_SchemaRework_v3.sql`

Adds the v3 snapshot columns:

- `SourceType`
- `SourceId`
- `IsSelected`
- `DocNumber`
- `DocDate`
- `Description`
- `BillName`
- `OriginalAmount`
- `OpenBalanceBefore`
- `TermName`
- `DiscountPercent`
- `DiscountAlreadyTaken`
- `DiscountDate`
- `DueDays`

Legacy temp columns are retained for compatibility.

Rollback:

- `TempCustomerPayment_SchemaRework_v3_rollback.sql`

### Step 2: Committed Detail Schema

`CustomerPaymentDetail_AddSourcePaymentNumber.sql`

This is the final committed-detail source-link script.

It:

- drops `SourceCustomerPaymentId`
- adds `SourcePaymentNumber INT NULL`

Rollback:

- `CustomerPaymentDetail_AddSourcePaymentNumber_rollback.sql`

### Step 3: Source Use Table

`CustomerPaymentSourceUse_Create.sql`

Creates the SQL-only table used for non-document source consumption, currently:

- `AsIncome`

This keeps prior unapplied funding used as income out of `CustomerPaymentDetail` while
still making source-balance recompute, delete, and edit reconstruction correct.

Rollback:

- `CustomerPaymentSourceUse_Create_rollback.sql`

### Step 4: Inject SP

`CustomerPayment_Inject_v3.sql`

Creates the v3 inject behavior for:

- edit-mode detail reconstruction
- edit-mode historical cutoff for selectable candidates
- open invoices
- credit memos
- unapplied payments
- CC fee rows
- consumed-credit informational rows

Edit-mode rules:

- rows already used by the payment being edited are always reconstructed
- new selectable invoice / credit memo / debit memo candidates are limited to `ShipDate <= PaymentDate`
- new selectable unapplied-payment candidates are limited to `PaymentDate <= PaymentDate`
- `ConsumedCredit` rows explain extra cash already consumed by later payments and reduce available budget in edit mode
- `ConsumedCredit` merges both:
  - document-linked source usage from `CustomerPaymentDetail`
  - non-document source usage from `CustomerPaymentSourceUse`

### Step 5: Temp GetList SP

`TempCustomerPayment_GetList_v3.sql`

Returns the explicit v3 temp-cart contract.

### Step 6: Temp InsertInvoice SP

`TempCustomerPayment_InsertInvoice_v3.sql`

Creates the v3 temp insert behavior and source typing.

### Step 7: Save SP

`CustomerPayment_Insert_v3.sql`

This is the critical save-path script.

It:

- reads `IsSelected` / `SourceType`
- handles `UnappliedPayment` funding through `#UnappliedPool`
- splits committed detail rows by funding source
- stores `SourcePaymentNumber`
- writes `CustomerPaymentSourceUse` rows for prior unapplied amounts taken as `AsIncome`
- recalculates affected source-payment headers from committed detail truth
- avoids header drift when a prior unapplied payment is partially reused and later edited

### Step 8: CC Fee SP

`CustomerPayment_InsertCCFee_v3.sql`

Creates v3 temp/cart behavior for `CCFee`.

### Step 9: Delete SP

`CustomerPayment_Delete_v3.sql`

Creates the v3-safe delete path.

It:

- blocks deleting a payment still used by another payment as source credit
- routes application delete requests through a dedicated stored procedure

### Step 10: Delete Trigger

`TRG_Delete_CustomerPaymentTx_v3.sql`

Updates the delete trigger so v3 source-credit behavior is handled during delete.

It:

- recalculates affected source-payment headers after delete
- blocks deleting a source payment still referenced by other payments
- preserves existing sales / journal / refund cleanup
- deletes matching `CustomerPaymentSourceUse` rows for deleted consuming payments

### Step 12: Header Recalc Script

`CustomerPayment_RecalcHeaderAmounts_v3.sql` (optional but recommended after deployment)

Use this one-time repair script after deploying the v3 source-credit fixes if any existing
`CustomerPayment.PaymentApplied` or `CustomerPayment.UnappliedAmount` headers have already drifted.

It recalculates headers from:

- the payment's own non-source detail rows
- credit memo usage
- `AsIncome`
- other payments consuming the payment through `SourcePaymentNumber`

Deployment note:

- this trigger is recreated by `DROP TRIGGER` + `CREATE TRIGGER`
- the rollback helper restores `TRG_Delete_CustomerPaymentTx_prev` if present

### Step 10: Report SP

`Report_CustomerPayment.sql` (optional)

## Procedure Creation Requirement

Stored procedures must be created with:

```sql
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO
```

before `CREATE PROCEDURE`.

The deployed v3 procedures should show:

- `ExecIsQuotedIdentOn = 1`
- `ExecIsAnsiNullsOn = 1`

for:

- `CustomerPayment_Inject`
- `CustomerPayment_Insert`
- `TempCustomerPayment_GetList`
- `CustomerPayment_InsertCCFee`
- `CustomerPayment_Delete`

Trigger metadata should also be verified for:

- `TRG_Delete_CustomerPaymentTx`

## Replaced Scripts

These old scripts were removed and replaced by:

- `CustomerPaymentDetail_AddSourcePaymentNumber.sql`
- `CustomerPaymentDetail_AddSourcePaymentNumber_rollback.sql`

## Rollback Order

If needed:

1. run `TRG_Delete_CustomerPaymentTx_v3_rollback.sql`
2. run `CustomerPayment_Delete_v3_rollback.sql`
3. run `CustomerPaymentSourceUse_Create_rollback.sql`
4. restore other SPs from their `_prev` versions
   - `CustomerPayment_Inject_prev`
   - `TempCustomerPayment_GetList_prev`
   - `TempCustomerPayment_InsertInvoice_prev`
   - `CustomerPayment_Insert_prev`
   - `CustomerPayment_InsertCCFee_prev`
5. run `CustomerPaymentDetail_AddSourcePaymentNumber_rollback.sql`
5. run `TempCustomerPayment_SchemaRework_v3_rollback.sql`

Stored-procedure rollback for steps 3-7 is handled by restoring the `_prev` objects in the database.

## Final Design Notes

- `SourcePaymentNumber` is the final source-link field.
- `SourceCustomerPaymentId` is obsolete and unstable.
- Unapplied payment funding is committed as positive invoice detail rows with `SourcePaymentNumber` metadata.
- The source payment's `UnappliedAmount` is reduced by `PaymentNumber`, not by `CustomerPaymentId`.
