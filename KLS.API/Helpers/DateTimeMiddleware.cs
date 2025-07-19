using System.Text.Json.Serialization;
using System.Text.Json;

namespace KLS.API.Helpers
{
    public class DateTimeMiddleware : JsonConverter<DateTime>
    {
        private readonly IHttpContextAccessor _httpContextAccessor;

        public DateTimeMiddleware(IHttpContextAccessor httpContextAccessor)
        {
            _httpContextAccessor = httpContextAccessor;
        }

        public override DateTime Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
        {
            // Deserialization: Assume the incoming DateTime is UTC and parse accordingly.
            return DateTime.SpecifyKind(reader.GetDateTime(), DateTimeKind.Utc);
        }

        public override void Write(Utf8JsonWriter writer, DateTime value, JsonSerializerOptions options)
        {
            // Serialization: Convert UTC DateTime to the target timezone.
            //var timeZoneId = _httpContextAccessor.HttpContext?.Items["Timezone"].ToString();
            var timeZoneId = Convert.ToString(_httpContextAccessor.HttpContext?.Items["Timezone"]);

            //if (!string.IsNullOrEmpty(StoreContext.UserTimezone))
            //    timeZoneId = StoreContext.UserTimezone;

            if (!string.IsNullOrEmpty(timeZoneId))
            {
                var timeZoneInfo = TimeZoneInfo.FindSystemTimeZoneById(timeZoneId);
                var convertedTime = TimeZoneInfo.ConvertTimeFromUtc(value, timeZoneInfo);
                writer.WriteStringValue(convertedTime);
            }
            else
            {
                // Default to UTC if no timezone is specified.
                writer.WriteStringValue(value);
            }
        }
    }
}
