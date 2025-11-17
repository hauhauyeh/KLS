using Microsoft.AspNetCore.Mvc.ModelBinding;

namespace KLS.API.Helpers
{
    public class NullableNumericModelBinderProvider : IModelBinderProvider
    {
        public IModelBinder? GetBinder(ModelBinderProviderContext context)
        {
            var type = context.Metadata.ModelType;

            if (type == typeof(int?) ||
                type == typeof(decimal?) ||
                type == typeof(double?) ||
                type == typeof(float?) ||
                type == typeof(long?))
            {
                return new NullableNumericModelBinder();
            }

            return null;
        }
    }

    public class NullableNumericModelBinder : IModelBinder
    {
        public Task BindModelAsync(ModelBindingContext context)
        {
            var rawValue = context.ValueProvider.GetValue(context.ModelName).FirstValue;

            // Treat null, empty, whitespace, or literal "null" as null
            if (string.IsNullOrWhiteSpace(rawValue) ||
                rawValue.Equals("null", StringComparison.OrdinalIgnoreCase))
            {
                context.Result = ModelBindingResult.Success(null);
                return Task.CompletedTask;
            }

            var type = context.ModelType;

            try
            {
                object? parsedValue = null;

                if (type == typeof(int?))
                    parsedValue = int.Parse(rawValue);

                else if (type == typeof(decimal?))
                    parsedValue = decimal.Parse(rawValue);

                else if (type == typeof(double?))
                    parsedValue = double.Parse(rawValue);

                else if (type == typeof(float?))
                    parsedValue = float.Parse(rawValue);

                else if (type == typeof(long?))
                    parsedValue = long.Parse(rawValue);

                context.Result = ModelBindingResult.Success(parsedValue);
            }
            catch
            {
                context.ModelState.TryAddModelError(context.ModelName, $"Invalid value '{rawValue}' for {context.ModelName}.");
            }

            return Task.CompletedTask;
        }
    }
}
