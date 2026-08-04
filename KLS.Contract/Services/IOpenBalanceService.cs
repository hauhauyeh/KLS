using KLS.Models;

namespace KLS.Contract.Services
{
    public interface IOpenBalanceService
    {
        /// <summary>The five cards plus the reconciliation banner. The whole screen.</summary>
        OpenBalanceStatusRes GetStatus();

        /// <summary>
        /// One section's current rows as a workbook. Populated, not blank --
        /// blank is only what an empty section produces.
        /// </summary>
        (byte[] Content, string FileName) Download(OpenBalanceSection section);

        /// <summary>All five sections in one book, for the audit file. Export only.</summary>
        (byte[] Content, string FileName) Export();

        /// <summary>Step 1. Parse and check the upload; write nothing.</summary>
        OpenBalancePreviewRes Preview(OpenBalancePreviewReq req);

        /// <summary>Step 2. Save the rows and post the journal, in one transaction.</summary>
        OpenBalanceImportRes Import(OpenBalanceCommitReq req);

        /// <summary>Remove one section's journal. The saved rows are kept.</summary>
        OpenBalanceStatusRes Unpost(OpenBalanceSectionReq req);
    }
}
