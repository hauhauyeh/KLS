namespace KLS.Common
{
    /// <summary>
    /// String constants for the EmailLog audit fields. Senders and the audit
    /// helper reference these instead of literals. See EmailLog system-wide
    /// audit plan (Data Model).
    /// </summary>
    public static class EmailAudit
    {
        public static class Category
        {
            public const string Document = "Document";
            public const string Customer = "Customer";
            public const string Account = "Account";
            public const string Website = "Website";
            public const string Notification = "Notification";
            public const string System = "System";
        }

        public static class EmailType
        {
            public const string SalesQuote = "SalesQuote";
            public const string Invoice = "Invoice";
            public const string PurchaseOrder = "PurchaseOrder";
            public const string PriceSheet = "PriceSheet";
            public const string Statement = "Statement";
            public const string ACHReceipt = "ACHReceipt";
            public const string WebOrderConfirmation = "WebOrderConfirmation";
            public const string WebOrderAdminNotification = "WebOrderAdminNotification";
            public const string ContactMessage = "ContactMessage";
            public const string CustomerRegistration = "CustomerRegistration";
            public const string PasswordReset = "PasswordReset";
            public const string EmailVerification = "EmailVerification";
            public const string AccountReady = "AccountReady";
        }

        public static class DocumentType
        {
            public const string SalesQuote = "SalesQuote";
            public const string Invoice = "Invoice";
            public const string PurchaseOrder = "PurchaseOrder";
            public const string Statement = "Statement";
            public const string PriceSheet = "PriceSheet";
            public const string ACHReceipt = "ACHReceipt";
            public const string Report = "Report";
        }

        public static class RelatedEntity
        {
            public const string Payee = "Payee";
            public const string UserAccount = "UserAccount";
            public const string SystemUser = "SystemUser";
        }

        public static class Source
        {
            public const string Manual = "Manual";
            public const string Scheduler = "Scheduler";
            public const string System = "System";
        }

        public static class DeliveryStatus
        {
            public const string Sent = "Sent";
            public const string Failed = "Failed";
            public const string Unknown = "Unknown";
            public const string Queued = "Queued";
        }
    }
}
