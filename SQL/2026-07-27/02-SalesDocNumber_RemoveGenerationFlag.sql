/*
SalesDocNumber cleanup after design change.

Generation is mandatory for new Sales rows once generation code is deployed.
Only display remains behind a feature flag.

Rollback: reinsert SALES_DOC_NUMBER_ENABLED only if needed for rollback testing.
*/

DELETE FROM dbo.SystemSetting
WHERE SettingKey = 'SALES_DOC_NUMBER_ENABLED';

