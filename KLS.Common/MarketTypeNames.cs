using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Common
{
    public static class MarketTypeNames
    {
        public const string Amazon = "Amazon";
        public const string Ebay = "Ebay";
        public const string Walmart = "Walmart";
        public const string ShipStation = "ShipStation";

        public static readonly string[] All = new[] { Amazon, Ebay, Walmart, ShipStation };

        public static bool IsValid(string marketType) => All.Contains(marketType);
    }
}
