namespace KLS.Models
{
    /// <summary>
    /// Serialised as a plain string so the client needs no enum mapping.
    /// Ordered by severity: the worst status among a batch's rows becomes the batch's,
    /// and the worst among the batches becomes the file's.
    /// </summary>
    public static class ImportPayNowStatus
    {
        public const string Ok = "Ok";

        public const string Warning = "Warning";

        public const string Error = "Error";

        /// <summary>Returns whichever of the two statuses is more severe.</summary>
        public static string Worst(string a, string b)
        {
            if (a == Error || b == Error) return Error;
            if (a == Warning || b == Warning) return Warning;
            return Ok;
        }
    }
}
