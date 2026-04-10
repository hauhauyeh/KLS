using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Common
{
    public static class CredentialEncryptor
    {
        public static string Encrypt(string plainText)
        {
            var key = Convert.FromBase64String(Constants.MarketplaceEncryptionKey!);
            using var aes = Aes.Create();
            aes.Key = key;
            aes.GenerateIV();

            using var encryptor = aes.CreateEncryptor();
            var plainBytes = Encoding.UTF8.GetBytes(plainText);
            var cipherBytes = encryptor.TransformFinalBlock(plainBytes, 0, plainBytes.Length);

            // Prepend IV to ciphertext for storage
            var result = new byte[aes.IV.Length + cipherBytes.Length];
            aes.IV.CopyTo(result, 0);
            cipherBytes.CopyTo(result, aes.IV.Length);
            return Convert.ToBase64String(result);
        }

        public static string Decrypt(string cipherText)
        {
            var key = Convert.FromBase64String(Constants.MarketplaceEncryptionKey!);
            var fullBytes = Convert.FromBase64String(cipherText);

            using var aes = Aes.Create();
            aes.Key = key;

            var iv = fullBytes[..16];
            var cipher = fullBytes[16..];
            aes.IV = iv;

            using var decryptor = aes.CreateDecryptor();
            var plainBytes = decryptor.TransformFinalBlock(cipher, 0, cipher.Length);
            return Encoding.UTF8.GetString(plainBytes);
        }
    }
}
