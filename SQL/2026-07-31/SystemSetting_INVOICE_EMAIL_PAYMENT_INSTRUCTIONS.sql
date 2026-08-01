IF NOT EXISTS (SELECT 1 FROM dbo.SystemSetting WHERE SettingKey = 'INVOICE_EMAIL_PAYMENT_INSTRUCTIONS')
BEGIN
    DECLARE @PaymentInstructions nvarchar(max) = N'<p><strong>Payment Instructions</strong></p>
<p>Please include the invoice number with your ACH or wire payment.</p>
<table>
  <tr><td>Beneficiary</td><td>GUS PACKAGING SOLUTIONS INC</td></tr>
  <tr><td>Account Number</td><td>2911032732</td></tr>
  <tr><td>Account Type</td><td>Checking Account</td></tr>
  <tr><td>Account Address</td><td>829 E CAMINO REAL AVE, ARCADIA, CA 91006-4428</td></tr>
  <tr><td>Bank Name</td><td>J.P. MORGAN CHASE BANK</td></tr>
  <tr><td>Bank Address</td><td>17247 Colima Rd., City of Industry, CA 91748</td></tr>
  <tr><td>Domestic Wire ABA</td><td>021000021</td></tr>
  <tr><td>ACH Routing Number</td><td>322271627</td></tr>
  <tr><td>International Wire SWIFT</td><td>CHASUS33XXX</td></tr>
  <tr><td>International Wire Address</td><td>JPMorgan Chase, 207 Park Ave., New York, NY 10017</td></tr>
</table>';

    INSERT INTO dbo.SystemSetting (SettingKey, SettingValue, DataType, Description, CreatedAt)
    VALUES (
        'INVOICE_EMAIL_PAYMENT_INSTRUCTIONS',
        @PaymentInstructions,
        'html',
        'Payment instructions included in invoice emails',
        SYSUTCDATETIME()
    );
END
