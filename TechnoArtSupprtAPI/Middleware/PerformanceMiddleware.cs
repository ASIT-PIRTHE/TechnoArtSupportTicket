using System.Diagnostics;

namespace TechnoArtSupprtAPI.Middleware
{
    public class PerformanceMiddleware
    {
        private readonly RequestDelegate _next;
        private readonly ILogger<PerformanceMiddleware> _logger;
        private const int SlowRequestThresholdMs = 500;

        public PerformanceMiddleware(
            RequestDelegate next,
            ILogger<PerformanceMiddleware> logger)
        {
            _next = next;
            _logger = logger;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            var stopwatch = Stopwatch.StartNew();
            var requestPath = context.Request.Path;

            try
            {
                await _next(context);
            }
            finally
            {
                stopwatch.Stop();
                var elapsed = stopwatch.ElapsedMilliseconds;

                if (elapsed > SlowRequestThresholdMs)
                {
                    _logger.LogWarning(
                        "SLOW REQUEST: {Method} {Path} took {ElapsedMs}ms — Status: {Status}",
                        context.Request.Method,
                        requestPath,
                        elapsed,
                        context.Response.StatusCode);
                }
                else
                {
                    _logger.LogDebug(
                        "{Method} {Path} → {Status} in {ElapsedMs}ms",
                        context.Request.Method,
                        requestPath,
                        context.Response.StatusCode,
                        elapsed);
                }
            }
        }
    }
}
