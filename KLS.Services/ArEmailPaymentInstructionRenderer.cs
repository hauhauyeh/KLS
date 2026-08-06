using KLS.Contract.Services;
using KLS.Models;
using System.Net;
using System.Text;

namespace KLS.Services
{
    public class ArEmailPaymentInstructionRenderer : IArEmailPaymentInstructionRenderer
    {
        public string Render(Company? company)
        {
            if (company == null)
                return string.Empty;

            var rows = BuildRows(company);
            if (rows.Count == 0)
                return string.Empty;

            var title = Clean(company.InvoicePaymentTitle);
            if (string.IsNullOrEmpty(title))
                title = "Payment Instructions";

            var html = new StringBuilder();
            html.AppendLine("""<div style="margin:20px 0 18px 0;">""");
            html.AppendLine($"""<p style="margin:0 0 8px 0;font-size:16px;color:#222222;"><strong>{Encode(title)}</strong></p>""");
            html.AppendLine("""<table cellpadding="7" cellspacing="0" style="border-collapse:collapse;border:1px solid #cfd7e6;font-size:14px;line-height:1.4;">""");

            foreach (var row in rows)
            {
                html.AppendLine("<tr>");
                html.AppendLine($"""<td style="border:1px solid #cfd7e6;font-weight:bold;background:#f4f6fa;color:#222222;white-space:nowrap;">{Encode(row.Label)}</td>""");
                html.AppendLine($"""<td style="border:1px solid #cfd7e6;color:#222222;">{Encode(row.Value)}</td>""");
                html.AppendLine("</tr>");
            }

            html.AppendLine("</table>");
            html.AppendLine("</div>");

            return html.ToString();
        }

        private static List<PaymentInstructionRow> BuildRows(Company company)
        {
            var rows = new List<PaymentInstructionRow>();

            AddIfPresent(rows, "Bank Name", company.InvoicePaymentBankName);
            AddIfPresent(rows, "Account Name", company.InvoicePaymentAccountName);
            AddIfPresent(rows, "Account Number", company.InvoicePaymentAccountNumber);

            var achRoutingNumber = FirstPresent(
                company.InvoicePaymentAchRoutingNumber,
                company.InvoicePaymentRoutingNumber);
            AddIfPresent(rows, "ACH Routing Number", achRoutingNumber);

            var zelle = FormatZelle(company.InvoicePaymentZelleEmail, company.InvoicePaymentZellePhone);
            AddIfPresent(rows, "Zelle", zelle);

            return rows;
        }

        private static void AddIfPresent(List<PaymentInstructionRow> rows, string label, string? value)
        {
            var cleanValue = Clean(value);
            if (!string.IsNullOrEmpty(cleanValue))
                rows.Add(new PaymentInstructionRow(label, cleanValue));
        }

        private static string? FirstPresent(params string?[] values)
        {
            foreach (var value in values)
            {
                var cleanValue = Clean(value);
                if (!string.IsNullOrEmpty(cleanValue))
                    return cleanValue;
            }

            return null;
        }

        private static string? FormatZelle(string? email, string? phone)
        {
            var cleanEmail = Clean(email);
            var cleanPhone = Clean(phone);

            if (!string.IsNullOrEmpty(cleanEmail) && !string.IsNullOrEmpty(cleanPhone))
                return $"{cleanEmail} / {cleanPhone}";

            return cleanEmail ?? cleanPhone;
        }

        private static string? Clean(string? value)
        {
            var cleanValue = value?.Trim();
            return string.IsNullOrEmpty(cleanValue) ? null : cleanValue;
        }

        private static string Encode(string value)
        {
            return WebUtility.HtmlEncode(value);
        }

        private sealed record PaymentInstructionRow(string Label, string Value);
    }
}
