using Microsoft.AspNetCore.Http;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Linq;
using System.Net;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using System.Xml;

namespace KLS.Common
{
    public static class Utilities
    {
        private const string DEFAULT_KEY = "#k!l@*?+s@<f$";

        private const int Keysize = 128;

        // This constant determines the number of iterations for the password bytes generation function.
        private const int DerivationIterations = 1000;

        public static string Encrypt(string? plainText)
        {
            if (string.IsNullOrEmpty(plainText))
                return null;

            // Salt and IV is randomly generated each time, but is preprended to encrypted cipher text
            // so that the same Salt and IV values can be used when decrypting.  
            var saltStringBytes = Generate128BitsOfRandomEntropy();
            var ivStringBytes = Generate128BitsOfRandomEntropy();
            var plainTextBytes = Encoding.UTF8.GetBytes(plainText ?? "");
            using (var password = new Rfc2898DeriveBytes(DEFAULT_KEY, saltStringBytes, DerivationIterations))
            {
                var keyBytes = password.GetBytes(Keysize / 8);
                using (var symmetricKey = Aes.Create())
                {
                    symmetricKey.BlockSize = 128;
                    symmetricKey.Mode = CipherMode.CBC;
                    symmetricKey.Padding = PaddingMode.PKCS7;
                    using (var encryptor = symmetricKey.CreateEncryptor(keyBytes, ivStringBytes))
                    {
                        using (var memoryStream = new MemoryStream())
                        {
                            using (var cryptoStream = new CryptoStream(memoryStream, encryptor, CryptoStreamMode.Write))
                            {
                                cryptoStream.Write(plainTextBytes, 0, plainTextBytes.Length);
                                cryptoStream.FlushFinalBlock();
                                // Create the final bytes as a concatenation of the random salt bytes, the random iv bytes and the cipher bytes.
                                var cipherTextBytes = saltStringBytes;
                                cipherTextBytes = cipherTextBytes.Concat(ivStringBytes).ToArray();
                                cipherTextBytes = cipherTextBytes.Concat(memoryStream.ToArray()).ToArray();
                                memoryStream.Close();
                                cryptoStream.Close();
                                var encrptedtext = Convert.ToBase64String(cipherTextBytes);
                                return encrptedtext;
                            }
                        }
                    }
                }
            }
        }

        public static string? Decrypt(string? cipherText)
        {
            if (string.IsNullOrEmpty(cipherText))
                return null;

            var allBytes = Convert.FromBase64String(cipherText);

            var salt = allBytes.Take(Keysize / 8).ToArray();          // 16
            var iv = allBytes.Skip(Keysize / 8).Take(16).ToArray(); // IV is always 16 for AES
            var ct = allBytes.Skip((Keysize / 8) + 16).ToArray();

            using var password = new Rfc2898DeriveBytes(DEFAULT_KEY, salt, DerivationIterations);
            var keyBytes = password.GetBytes(Keysize / 8);

            using var aes = Aes.Create();
            aes.BlockSize = 128;
            aes.Mode = CipherMode.CBC;
            aes.Padding = PaddingMode.PKCS7;

            using var decryptor = aes.CreateDecryptor(keyBytes, iv);
            using var ms = new MemoryStream(ct);
            using var cs = new CryptoStream(ms, decryptor, CryptoStreamMode.Read);
            using var sr = new StreamReader(cs, Encoding.UTF8);
            return sr.ReadToEnd();
        }


        //public static string? Decrypt(string? cipherText)
        //{
        //    if (string.IsNullOrEmpty(cipherText))
        //    {
        //        return null;
        //    }

        //    // Get the complete stream of bytes that represent:
        //    // [32 bytes of Salt] + [16 bytes of IV] + [n bytes of CipherText]
        //    var cipherTextBytesWithSaltAndIv = Convert.FromBase64String(cipherText);
        //    // Get the saltbytes by extracting the first 16 bytes from the supplied cipherText bytes.
        //    var saltStringBytes = cipherTextBytesWithSaltAndIv.Take(Keysize / 8).ToArray();
        //    // Get the IV bytes by extracting the next 16 bytes from the supplied cipherText bytes.
        //    var ivStringBytes = cipherTextBytesWithSaltAndIv.Skip(Keysize / 8).Take(Keysize / 8).ToArray();
        //    // Get the actual cipher text bytes by removing the first 64 bytes from the cipherText string.
        //    var cipherTextBytes = cipherTextBytesWithSaltAndIv.Skip((Keysize / 8) * 2).Take(cipherTextBytesWithSaltAndIv.Length - ((Keysize / 8) * 2)).ToArray();

        //    using (var password = new Rfc2898DeriveBytes(DEFAULT_KEY, saltStringBytes, DerivationIterations))
        //    {
        //        var keyBytes = password.GetBytes(Keysize / 8);
        //        using (var symmetricKey = Aes.Create())
        //        {
        //            symmetricKey.BlockSize = 128;
        //            symmetricKey.Mode = CipherMode.CBC;
        //            symmetricKey.Padding = PaddingMode.PKCS7;
        //            using (var decryptor = symmetricKey.CreateDecryptor(keyBytes, ivStringBytes))
        //            {
        //                using (var memoryStream = new MemoryStream(cipherTextBytes))
        //                {
        //                    using (var cryptoStream = new CryptoStream(memoryStream, decryptor, CryptoStreamMode.Read))
        //                    {
        //                        var plainTextBytes = new byte[cipherTextBytes.Length];
        //                        var decryptedByteCount = cryptoStream.Read(plainTextBytes, 0, plainTextBytes.Length);
        //                        memoryStream.Close();
        //                        cryptoStream.Close();
        //                        return Encoding.UTF8.GetString(plainTextBytes, 0, decryptedByteCount);
        //                    }
        //                }
        //            }
        //        }
        //    }
        //}

        private static byte[] Generate128BitsOfRandomEntropy()
        {
            var randomBytes = new byte[16]; // 16 Bytes will give us 128 bits.
            using (var rngCsp = RandomNumberGenerator.Create())
            {
                // Fill the array with cryptographically secure random bytes.
                rngCsp.GetBytes(randomBytes);
            }
            return randomBytes;
        }

        public static decimal? Rounding(decimal? price, int? roundPoint)
        {
            if (price.HasValue && roundPoint.HasValue && roundPoint.Value > 0)
            {
                var roundUpPriceValue = Math.Round(price.Value, roundPoint.Value, MidpointRounding.AwayFromZero);

                return roundUpPriceValue;
            }

            return price;
        }

        public static string GetIpAddress(HttpContext httpContext)
        {
            var ipadd = httpContext.Connection.RemoteIpAddress.ToString();

            if (ipadd == "::1")
            {
                IPAddress[] ipaddress = Dns.GetHostEntry(Dns.GetHostName()).AddressList;

                if (ipaddress.Count() > 2)
                {
                    ipadd = ipaddress[2].ToString();
                }
                else if (ipaddress.Count() == 2)
                {
                    ipadd = ipaddress[1].ToString();
                }
            }

            return ipadd;
        }

        public static DateTime GetPreviousWeekDay(DayOfWeek dow)
        {
            int currentDay = (int)DateTime.Now.DayOfWeek, gotoDay = (int)dow;
            return DateTime.Now.AddDays(-7).AddDays(gotoDay - currentDay);
        }

        public static int GetTotalPages(int totalrows, int pagesize)
        {
            return (int)Math.Ceiling(totalrows / (decimal)pagesize);
        }

        public static string DigitToWord(int digit)
        {
            switch (digit % 10)
            {
                case 1:
                    return digit + "st";
                case 2:
                    return digit + "nd";
                case 3:
                    return digit + "rd";
                default:
                    return digit + "th";
            }
        }

        public static string EAN13(string DataToEncode)
        {
            string DataToPrint = "";

            if (string.IsNullOrEmpty(DataToEncode))
                return DataToPrint;

            string OnlyCorrectData = "";
            int CurrentCharNum;
            // Check to make sure data is numeric and remove dashes, etc.
            int StringLength = DataToEncode.Length;
            for (int I = 1; I <= StringLength; I++)
            {
                // Add all numbers to OnlyCorrectData string
                // 2006.2 BDA modified the next 3 lines for compatibility with different office versions
                // If IsNumeric(Mid(DataToEncode, I, 1)) Then OnlyCorrectData = OnlyCorrectData && Mid(DataToEncode, I, 1)
                CurrentCharNum = DataToEncode[I - 1];
                if (CurrentCharNum > 47 && CurrentCharNum < 58)
                    OnlyCorrectData = OnlyCorrectData + DataToEncode.Substring(I - 1, 1);
            }
            // 2006.2 BDA added the next line for general compatibility
            StringLength = OnlyCorrectData.Length;
            if (StringLength < 12)
                OnlyCorrectData = "0000000000000";
            if (StringLength == 16)
                OnlyCorrectData = "0000000000000";
            if (StringLength == 13)
                OnlyCorrectData = OnlyCorrectData.Substring(0, 12);
            if (StringLength == 15)
                OnlyCorrectData = OnlyCorrectData.Substring(0, 12) + "" + OnlyCorrectData.Substring(13, 2);
            if (StringLength > 17)
                OnlyCorrectData = OnlyCorrectData.Substring(0, 12) + "" + OnlyCorrectData.Substring(13, 5);
            string EAN2AddOn = "";
            string EAN5AddOn = "";
            string Encoding = "";
            // 2006.2 BDA added the next line for general compatibility
            StringLength = OnlyCorrectData.Length;
            if (StringLength == 17)
                EAN5AddOn = OnlyCorrectData.Substring(12, 5);
            if (StringLength == 14)
                EAN2AddOn = OnlyCorrectData.Substring(12, 2);
            // Remove digit number from add-ons and check digit
            DataToEncode = OnlyCorrectData.Substring(0, 12);
            // Calculate Check Digit
            int Factor = 3;
            int WeightedTotal = 0;
            for (int I = DataToEncode.Length; I >= 1; I += -1)
            {
                // Get the value of each number starting at the end
                CurrentCharNum = int.Parse(DataToEncode.Substring(I - 1, 1));
                // Multiply by the weighting factor which is 3,1,3,1...
                // and add the sum together
                WeightedTotal = WeightedTotal + CurrentCharNum * Factor;
                // Change factor for next calculation
                Factor = 4 - Factor;
            }
            // Find the CheckDigit by finding the number + WeightedTotal that = a multiple of 10
            // Divide by 10, get the remainder and subtract from 10
            int II = (WeightedTotal % 10);
            int CheckDigit;
            if (II != 0)
                CheckDigit = (10 - II);
            else
                CheckDigit = 0;
            // Encode the leading digit into the left half of the EAN-13 symbol
            // by using variable parity between character sets A and B
            int LeadingDigit = int.Parse(DataToEncode.Substring(0, 1));
            switch (LeadingDigit)
            {
                case 0:
                    {
                        Encoding = "AAAAAACCCCCC";
                        break;
                    }

                case 1:
                    {
                        Encoding = "AABABBCCCCCC";
                        break;
                    }

                case 2:
                    {
                        Encoding = "AABBABCCCCCC";
                        break;
                    }

                case 3:
                    {
                        Encoding = "AABBBACCCCCC";
                        break;
                    }

                case 4:
                    {
                        Encoding = "ABAABBCCCCCC";
                        break;
                    }

                case 5:
                    {
                        Encoding = "ABBAABCCCCCC";
                        break;
                    }

                case 6:
                    {
                        Encoding = "ABBBAACCCCCC";
                        break;
                    }

                case 7:
                    {
                        Encoding = "ABABABCCCCCC";
                        break;
                    }

                case 8:
                    {
                        Encoding = "ABABBACCCCCC";
                        break;
                    }

                case 9:
                    {
                        Encoding = "ABBABACCCCCC";
                        break;
                    }
            }
            // Add the check digit to the end of the barcode && remove the leading digit
            DataToEncode = DataToEncode.Substring(1, 11) + "" + CheckDigit;
            // Determine character to print for proper barcoding
            string CurrentEncoding;
            StringLength = DataToEncode.Length;
            for (int I = 1; I <= StringLength; I++)
            {
                // Get the ASCII value of each number excluding the first number because
                // it is encoded with variable parity
                CurrentCharNum = DataToEncode[I - 1];
                CurrentEncoding = Encoding.Substring(I - 1, 1);
                // Print different barcodes according to the location of the CurrentChar and CurrentEncoding
                switch (CurrentEncoding)
                {
                    case "A":
                        {
                            DataToPrint = DataToPrint + (char)(CurrentCharNum);
                            break;
                        }

                    case "B":
                        {
                            DataToPrint = DataToPrint + (char)(CurrentCharNum + 17);
                            break;
                        }

                    case "C":
                        {
                            DataToPrint = DataToPrint + (char)(CurrentCharNum + 27);
                            break;
                        }
                }
                // Add in the 1st character along with guard patterns
                switch (I)
                {
                    case 1:
                        {
                            // For the LeadingDigit, print the human readable character,
                            // the normal guard pattern, and then the rest of the barcode
                            if (LeadingDigit > 4)
                                DataToPrint = (char)((LeadingDigit + 48) + 64) + "(" + DataToPrint;
                            if (LeadingDigit < 5)
                                DataToPrint = (char)((LeadingDigit + 48) + 37) + "(" + DataToPrint;
                            break;
                        }

                    case 6:
                        {
                            // Print the center guard pattern after the 6th character
                            DataToPrint = DataToPrint + "*";
                            break;
                        }

                    case 12:
                        {
                            // For the last character (12), print the the normal guard pattern after the barcode
                            DataToPrint = DataToPrint + "(";
                            break;
                        }
                }
            }
            // Process add-ons if they exist
            if (EAN2AddOn.Length == 2)
                DataToPrint = DataToPrint + " " + ProcessEAN2AddOn(EAN2AddOn);
            if (EAN5AddOn.Length == 5)
                DataToPrint = DataToPrint + " " + ProcessEAN5AddOn(EAN5AddOn);
            // Return PrintableString
            return DataToPrint;
        }

        private static string ProcessEAN2AddOn(string EAN2AddOn)
        {
            // Process the 2 digit add on
            string EANAddOnToPrint = "";
            string Encoding = "";
            string CurrentChar;
            string CurrentEncoding;
            if (EAN2AddOn.Length == 2)
            {
                // Get encoding for add on
                for (int I = 0; I <= 99; I += 4)
                {
                    if (int.Parse(EAN2AddOn) == I)
                        Encoding = "AA";
                    if (int.Parse(EAN2AddOn) == I + 1)
                        Encoding = "AB";
                    if (int.Parse(EAN2AddOn) == I + 2)
                        Encoding = "BA";
                    if (int.Parse(EAN2AddOn) == I + 3)
                        Encoding = "BB";
                }
                for (int I = 1; I <= EAN2AddOn.Length; I++)
                {
                    // Get the value of each number
                    // It is encoded with variable parity
                    CurrentChar = EAN2AddOn.Substring(I - 1, 1);
                    CurrentEncoding = Encoding.Substring(I - 1, 1);
                    // Print different barcodes according to the location of the CurrentChar and CurrentEncoding
                    switch (CurrentEncoding)
                    {
                        case "A":
                            {
                                if (CurrentChar == "0")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(34);
                                if (CurrentChar == "1")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(35);
                                if (CurrentChar == "2")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(36);
                                if (CurrentChar == "3")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(37);
                                if (CurrentChar == "4")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(38);
                                if (CurrentChar == "5")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(44);
                                if (CurrentChar == "6")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(46);
                                if (CurrentChar == "7")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(47);
                                if (CurrentChar == "8")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(58);
                                if (CurrentChar == "9")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(59);
                                break;
                            }

                        case "B":
                            {
                                if (CurrentChar == "0")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(122);
                                if (CurrentChar == "1")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(61);
                                if (CurrentChar == "2")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(63);
                                if (CurrentChar == "3")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(64);
                                if (CurrentChar == "4")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(91);
                                if (CurrentChar == "5")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(92);
                                if (CurrentChar == "6")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(93);
                                if (CurrentChar == "7")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(95);
                                if (CurrentChar == "8")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(123);
                                if (CurrentChar == "9")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(125);
                                break;
                            }
                    }
                    // Add in the space && add-on guard pattern
                    switch (I)
                    {
                        case 1:
                            {
                                EANAddOnToPrint = (char)(43) + EANAddOnToPrint + (char)(33);
                                break;
                            }

                        case 2:
                            {

                                break;
                            }
                    }
                }
            }
            return EANAddOnToPrint;
        }

        private static string ProcessEAN5AddOn(string EAN5AddOn)
        {

            string EANAddOnToPrint = "";
            string Encoding = "";

            if (EAN5AddOn.Length == 5)
            {
                // Get the check digit for the add on
                int Factor = 3;
                int WeightedTotal = 0;
                for (int I = EAN5AddOn.Length; I >= 1; I += -1)
                {
                    // Get the value of each number starting at the end
                    int CurrentCharNum = int.Parse(EAN5AddOn.Substring(I - 1, 1));
                    // Multiply by the weighting factor which is 3,9,3,9.
                    // and add the sum together
                    if (Factor == 3)
                        WeightedTotal = WeightedTotal + CurrentCharNum * 3;
                    if (Factor == 1)
                        WeightedTotal = WeightedTotal + CurrentCharNum * 9;
                    // Change factor for next calculation
                    Factor = 4 - Factor;
                }
                // Find the CheckDigit by extracting the right-most number from WeightedTotal
                int CheckDigit = int.Parse(WeightedTotal.ToString().Substring(WeightedTotal.ToString().Length - 1, 1));
                // Encode the add-on CheckDigit into the number sets
                // by using variable parity between character sets A and B
                switch (CheckDigit)
                {
                    case 0:
                        {
                            Encoding = "BBAAA";
                            break;
                        }

                    case 1:
                        {
                            Encoding = "BABAA";
                            break;
                        }

                    case 2:
                        {
                            Encoding = "BAABA";
                            break;
                        }

                    case 3:
                        {
                            Encoding = "BAAAB";
                            break;
                        }

                    case 4:
                        {
                            Encoding = "ABBAA";
                            break;
                        }

                    case 5:
                        {
                            Encoding = "AABBA";
                            break;
                        }

                    case 6:
                        {
                            Encoding = "AAABB";
                            break;
                        }

                    case 7:
                        {
                            Encoding = "ABABA";
                            break;
                        }

                    case 8:
                        {
                            Encoding = "ABAAB";
                            break;
                        }

                    case 9:
                        {
                            Encoding = "AABAB";
                            break;
                        }
                }
                // Determine the characters to print for proper barcoding
                for (int I = 1; I <= EAN5AddOn.Length; I++)
                {
                    // Get the value of each number encoded with variable parity
                    string CurrentChar = EAN5AddOn.Substring(I - 1, 1);
                    string CurrentEncoding = Encoding.Substring(I - 1, 1);
                    // Print different barcodes according to the location of the CurrentChar and CurrentEncoding
                    switch (CurrentEncoding)
                    {
                        case "A":
                            {
                                if (CurrentChar == "0")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(34);
                                if (CurrentChar == "1")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(35);
                                if (CurrentChar == "2")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(36);
                                if (CurrentChar == "3")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(37);
                                if (CurrentChar == "4")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(38);
                                if (CurrentChar == "5")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(44);
                                if (CurrentChar == "6")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(46);
                                if (CurrentChar == "7")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(47);
                                if (CurrentChar == "8")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(58);
                                if (CurrentChar == "9")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(59);
                                break;
                            }

                        case "B":
                            {
                                if (CurrentChar == "0")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(122);
                                if (CurrentChar == "1")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(61);
                                if (CurrentChar == "2")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(63);
                                if (CurrentChar == "3")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(64);
                                if (CurrentChar == "4")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(91);
                                if (CurrentChar == "5")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(92);
                                if (CurrentChar == "6")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(93);
                                if (CurrentChar == "7")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(95);
                                if (CurrentChar == "8")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(123);
                                if (CurrentChar == "9")
                                    EANAddOnToPrint = EANAddOnToPrint + (char)(125);
                                break;
                            }
                    }
                    // Add in the space && add-on guard pattern
                    switch (I)
                    {
                        case 1:
                            {
                                EANAddOnToPrint = (char)(43) + EANAddOnToPrint + (char)(33);
                                break;
                            }

                        case 2:
                            {
                                EANAddOnToPrint = EANAddOnToPrint + (char)(33);
                                break;
                            }

                        case 3:
                            {
                                EANAddOnToPrint = EANAddOnToPrint + (char)(33);
                                break;
                            }

                        case 4:
                            {
                                EANAddOnToPrint = EANAddOnToPrint + (char)(33);
                                break;
                            }

                        case 5:
                            {
                                break;
                            }
                    }
                }
            }
            return EANAddOnToPrint;
        }

        public static DateTime ConvertToUtc(DateTime localTime, string userTimeZoneId)
        {
            // Get the user's timezone — support both Windows ("India Standard Time") and IANA ("Asia/Kolkata") formats
            TimeZoneInfo tz;
            try
            {
                tz = TimeZoneInfo.FindSystemTimeZoneById(userTimeZoneId);
            }
            catch (TimeZoneNotFoundException)
            {
                // Fallback for cross-platform apps
                tz = TimeZoneInfo.FindSystemTimeZoneById("UTC");
            }

            // Always treat the input as a wall-clock time in user's timezone
            var unspecified = DateTime.SpecifyKind(localTime, DateTimeKind.Unspecified);

            // Convert that to UTC
            var utc = TimeZoneInfo.ConvertTimeToUtc(unspecified, tz);

            return DateTime.SpecifyKind(utc, DateTimeKind.Utc);
        }

        public static DateTime ConvertFromUtcToLocal(DateTime utcTime, string userTimeZoneId)
        {
            // Get the user's timezone — support both Windows ("India Standard Time") and IANA ("Asia/Kolkata") formats
            TimeZoneInfo tz;
            try
            {
                tz = TimeZoneInfo.FindSystemTimeZoneById(userTimeZoneId);
            }
            catch (TimeZoneNotFoundException)
            {
                // Fallback if timezone not found
                tz = TimeZoneInfo.FindSystemTimeZoneById("UTC");
            }

            // Ensure the input is treated as UTC
            var utc = DateTime.SpecifyKind(utcTime, DateTimeKind.Utc);

            // Convert UTC -> user's local time
            var local = TimeZoneInfo.ConvertTimeFromUtc(utc, tz);

            return DateTime.SpecifyKind(local, DateTimeKind.Unspecified);
        }

        public static string? GetLast4(string? accountNumber)
        {
            if (string.IsNullOrWhiteSpace(accountNumber))
                return null;

            accountNumber = accountNumber.Trim();

            return accountNumber.Length <= 4
                ? accountNumber
                : accountNumber.Substring(accountNumber.Length - 4);
        }
    }
}
