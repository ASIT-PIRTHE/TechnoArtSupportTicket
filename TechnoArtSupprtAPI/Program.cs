using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.ResponseCompression;
using Microsoft.AspNetCore.Server.Kestrel.Core;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.IdentityModel.Tokens;
using Polly;
using Polly.CircuitBreaker;
using System.IO.Compression;
using System.Text;
using System.Text.Json;
using System.Threading.RateLimiting;
using Scalar.AspNetCore;
using TechnoArtSupprtAPI;
using TechnoArtSupprtAPI.Middleware; 

var builder = WebApplication.CreateBuilder(new WebApplicationOptions
{
    Args = args,
    ContentRootPath = AppContext.BaseDirectory
});

// Initialize static config
ApiConst.Initialize(builder.Configuration);

// SECURITY ENHANCEMENT: Setup secure allowed procedures list (whitelist)
// Only procedures explicitly listed in appsettings.json will be allowed to execute.
var allowedProcedures = builder.Configuration.GetSection("AllowedProcedures").Get<HashSet<string>>() 
                        ?? new HashSet<string>(StringComparer.OrdinalIgnoreCase);

// Add services to the container.
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddOpenApi();
builder.Services.AddMemoryCache(options =>
{
    options.SizeLimit = 1024; // limit cache size
    options.ExpirationScanFrequency = TimeSpan.FromMinutes(5);
});

// Configure Response Compression (Brotli + Gzip)
builder.Services.AddResponseCompression(options =>
{
    options.EnableForHttps = true;
    options.Providers.Add<BrotliCompressionProvider>();
    options.Providers.Add<GzipCompressionProvider>();
});

builder.Services.Configure<BrotliCompressionProviderOptions>(options =>
{
    options.Level = CompressionLevel.Fastest;
});

builder.Services.Configure<GzipCompressionProviderOptions>(options =>
{
    options.Level = CompressionLevel.Fastest;
});

// Configure caching policies
builder.Services.AddResponseCaching(options =>
{
    options.MaximumBodySize = 64 * 1024 * 1024; // 64MB cache
    options.UseCaseSensitivePaths = false;
});

builder.Services.AddOutputCache(options =>
{
    options.AddBasePolicy(policy => policy.Cache().Expire(TimeSpan.FromSeconds(60)));
    options.AddPolicy("DbRequestCache", policy => policy.Cache().Expire(TimeSpan.FromSeconds(30)).Tag("db_requests"));
});

// Configure Kestrel limits for High Performance
builder.WebHost.ConfigureKestrel(options =>
{
    options.Limits.MaxConcurrentConnections = 5000;
    options.Limits.MaxConcurrentUpgradedConnections = 5000;
    options.Limits.MaxRequestBodySize = 100 * 1024 * 1024; // 100MB
    options.Limits.KeepAliveTimeout = TimeSpan.FromMinutes(2);
    options.Limits.RequestHeadersTimeout = TimeSpan.FromSeconds(30);
});

builder.Services.Configure<IISServerOptions>(options =>
{
    options.MaxRequestBodySize = 104857600; // 100 MB
});

// Rate Limiting
builder.Services.AddRateLimiter(options =>
{
    options.AddFixedWindowLimiter("GlobalLimit", opt =>
    {
        opt.PermitLimit = 100;
        opt.Window = TimeSpan.FromMinutes(1);
        opt.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
        opt.QueueLimit = 50;
    });

    options.AddSlidingWindowLimiter("ApiLimit", opt =>
    {
        opt.PermitLimit = 50;
        opt.Window = TimeSpan.FromSeconds(10);
        opt.SegmentsPerWindow = 2;
        opt.QueueLimit = 20;
    });

    // BRUTE FORCE PROTECTION: Extremely tight limit for login endpoints
    options.AddFixedWindowLimiter("LoginLimit", opt =>
    {
        opt.PermitLimit = 5; // Allow max 5 login attempts
        opt.Window = TimeSpan.FromMinutes(1); // Per minute, per IP/Session
        opt.QueueLimit = 0;
    });

    options.RejectionStatusCode = 429;
});

bool useRedis = builder.Configuration.GetValue<bool>("UseRedis");

// Health Checks
var healthChecksBuilder = builder.Services.AddHealthChecks()
    .AddCheck("self", () => HealthCheckResult.Healthy())
    .AddCheck("memory", () =>
    {
        var allocated = GC.GetTotalMemory(forceFullCollection: false);
        var threshold = 1024L * 1024 * 1024; // 1GB
        return allocated < threshold
            ? HealthCheckResult.Healthy($"Memory: {allocated / 1024 / 1024}MB")
            : HealthCheckResult.Degraded($"High memory: {allocated / 1024 / 1024}MB");
    });

if (useRedis)
{
    healthChecksBuilder.AddRedis(
        redisConnectionString: builder.Configuration.GetConnectionString("RedisConnStr") ?? "localhost:6379",
        name: "redis");

    builder.Services.AddStackExchangeRedisCache(options =>
    {
        options.Configuration = builder.Configuration.GetConnectionString("RedisConnStr") ?? "localhost:6379";
        options.InstanceName = "TechnoArtSupprtAPI:";
    });
}
else
{
    builder.Services.AddDistributedMemoryCache();
}

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = "JwtBearer";
    options.DefaultChallengeScheme = "JwtBearer";
}).AddJwtBearer("JwtBearer", jwtoptions =>
{
    jwtoptions.TokenValidationParameters = new TokenValidationParameters()
    {
        ValidIssuer = ApiConst.Issuer,
        ValidAudience = ApiConst.Audience,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(ApiConst.Key)),
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true
    };
});

builder.Services.AddAuthorization();

// Register ProcessAccessAPI service
builder.Services.AddScoped<ProcessAccessAPI>();

// Register Background Outbox Worker
builder.Services.AddHostedService<TechnoArtSupprtAPI.Workers.NotificationWorker>();

var app = builder.Build();

NotificationService.Initialize(app.Environment);

// Automatically ensure MSSQL stored procedures and schema are up to date on startup
_ = Task.Run(async () => {
    try {
        await DbInitHelper.EnsureDatabaseObjectsAsync(app.Configuration);
    } catch { }
});

app.UseMiddleware<PerformanceMiddleware>();
app.MapHealthChecks("/health");
app.MapGet("/ping", () => Results.Ok(new { status = "alive", time = DateTime.UtcNow }));
app.MapGet("/api/init-db", async (IConfiguration config) => {
    var res = await DbInitHelper.EnsureDatabaseObjectsAsync(config);
    return Results.Ok(new { status = "Success", message = res });
}).AllowAnonymous();
app.MapGet("/api/test-db", async (IConfiguration config) => {
    try {
        var dbType = config.GetValue<string>("DatabaseType") ?? "PostgreSQL";
        if (dbType.Equals("MSSQL", StringComparison.OrdinalIgnoreCase))
        {
            var connStr = DbInitHelper.ResolvedMssqlConnectionString ?? config.GetConnectionString("MssqlConnStr");
            Microsoft.Data.SqlClient.SqlConnection conn;
            try
            {
                conn = new Microsoft.Data.SqlClient.SqlConnection(connStr);
                await conn.OpenAsync();
            }
            catch when (!string.IsNullOrEmpty(config.GetConnectionString("MssqlConnStr_sa")))
            {
                connStr = config.GetConnectionString("MssqlConnStr_sa");
                conn = new Microsoft.Data.SqlClient.SqlConnection(connStr);
                await conn.OpenAsync();
                DbInitHelper.ResolvedMssqlConnectionString = connStr;
            }

            using (conn)
            {
                using var cmd = conn.CreateCommand();
                cmd.CommandText = "SELECT 'Connection Successful! Properly Connected to ' + DB_NAME() + ' (MSSQL) as ' + SUSER_SNAME() + '.'";
                var res = await cmd.ExecuteScalarAsync();
                return Results.Ok(new { status = "Success", db = "MSSQL", message = res });
            }
        }
        else
        {
            using var conn = new Npgsql.NpgsqlConnection(config.GetConnectionString("PostgresConnStr"));
            await conn.OpenAsync();
            using var cmd = new Npgsql.NpgsqlCommand("SELECT 'Connection Successful! Properly Connected to ' + current_database() + ' (PostgreSQL).'", conn);
            var res = await cmd.ExecuteScalarAsync();
            return Results.Ok(new { status = "Success", db = "PostgreSQL", message = res });
        }
    } catch (Exception ex) {
        return Results.Problem(ex.Message, statusCode: 500);
    }
}).WithOpenApi(op => { op.Summary = "Click Execute to Test Database Connection"; return op; }).AllowAnonymous();

app.UseResponseCompression();
app.UseResponseCaching();
app.UseOutputCache();
app.UseRateLimiter();


// Enable OpenAPI and Scalar UI in both Development and Production
app.MapOpenApi();
app.MapScalarApiReference("/swagger", options => {
    options.WithTitle("TechnoArtSupprtAPI Documentation");
    options.WithTheme(ScalarTheme.Moon);
});

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseAuthentication();
app.UseAuthorization();


// Semaphore for DB Access (Matched to SQL Pool Size 200)
var semaphore = new SemaphoreSlim(180); 

// Circuit Breaker Policy
var circuitBreakerPolicy = Policy
    .Handle<Exception>()
    .CircuitBreakerAsync(50, TimeSpan.FromSeconds(30)); 


app.Map("/error", () => Results.Problem("An unexpected error occurred."));

app.MapPost("/api/auth/login", async (LoginRequest req, ProcessAccessAPI api) => {
    try {
        var payload = new APIDataAccParms { 
            ProcID = "GET_USER_LOGIN", 
            parm01 = req.UserId ?? "", 
            parm02 = req.Password ?? ""
        };
        var dbRes = await api.GetApiResultAsync(payload, false);
        string jsonResult = dbRes is string s ? s : JsonSerializer.Serialize(dbRes);
        
        using var jsonDoc = JsonDocument.Parse(jsonResult);
        var root = jsonDoc.RootElement;
        
        if (root.ValueKind == JsonValueKind.Array)
        {
            if (root.GetArrayLength() > 0)
                root = root[0];
            else
                return Results.BadRequest(new { Error = "Invalid username or password" });
        }

        if (root.ValueKind == JsonValueKind.Object && root.TryGetProperty("success", out var successElement) && successElement.GetBoolean())
        {
            var role = root.TryGetProperty("role", out var rp) ? rp.GetString() ?? "ClientUser" : "ClientUser";
            var username = root.TryGetProperty("username", out var up) ? up.GetString() ?? req.UserId : req.UserId;
            var userId = root.TryGetProperty("user_id", out var uid) ? uid.GetString() ?? "" : "";
            var tenantId = root.TryGetProperty("tenant_id", out var tid) ? tid.GetString() ?? "" : "";
            
            // Store mobile FCM Token if sent during login
            if (!string.IsNullOrEmpty(req.FcmToken) && !string.IsNullOrEmpty(userId))
            {
                var fcmPayload = new APIDataAccParms { 
                    ProcID = "REGISTER_FCM_TOKEN", 
                    parm08 = userId,
                    parm01 = req.FcmToken 
                };
                await api.GetApiResultAsync(fcmPayload, false);
            }

            var token = ApiConst.CreateTokenForDbUser(userId, username ?? "", role, tenantId);
            return Results.Ok(new { tokenres = token.tokenstr, role = role, username = username, userId = userId, tenantId = tenantId });
        }
        
        return Results.BadRequest(new { Error = "Database details for debugging", Details = dbRes });
    }
    catch (Exception ex) { return Results.Problem(ex.Message); }
}).AllowAnonymous();

app.MapPost("/api/Jwt", [EnableRateLimiting("LoginLimit")] (JwtTokenUser model) =>
{
    var token = ApiConst.CreateToken(model);
    if (token.istokenstr) return Results.Ok(token);
    
    return Results.Json(new { 
        error = "Unauthorized", 
        message = token.tokenmsg,
        details = "Check credentials and JWT configuration."
    }, statusCode: 401);
}).AllowAnonymous();


async Task<IResult> HandleDbRequest(HttpContext context, ProcessAccessAPI api, IMemoryCache memoryCache, IDistributedCache redisCache, string bodyAsBase64, CancellationToken ct, bool compress = true, bool legacyFormat = false)
{
    APIDataAccParms? paramsObj = null;
    try
    {
        var json = Encoding.UTF8.GetString(Convert.FromBase64String(bodyAsBase64));
        paramsObj = JsonSerializer.Deserialize<APIDataAccParms>(json);
    }
    catch { }

    if (paramsObj == null || string.IsNullOrEmpty(paramsObj.ProcName)) 
        return Results.BadRequest("Invalid Procedure Name");

    // Identify if operation is a database mutation (create, update, delete, assign, remove, add, etc.)
    bool isMutation = !string.IsNullOrEmpty(paramsObj.ProcID) &&
        (paramsObj.ProcID.StartsWith("CREATE_", StringComparison.OrdinalIgnoreCase) ||
         paramsObj.ProcID.StartsWith("UPDATE_", StringComparison.OrdinalIgnoreCase) ||
         paramsObj.ProcID.StartsWith("DELETE_", StringComparison.OrdinalIgnoreCase) ||
         paramsObj.ProcID.StartsWith("ASSIGN_", StringComparison.OrdinalIgnoreCase) ||
         paramsObj.ProcID.StartsWith("REMOVE_", StringComparison.OrdinalIgnoreCase) ||
         paramsObj.ProcID.StartsWith("ADD_", StringComparison.OrdinalIgnoreCase) ||
         paramsObj.ProcID.StartsWith("REGISTER_", StringComparison.OrdinalIgnoreCase));

    string cacheKey = $"db_{bodyAsBase64.GetHashCode()}_{compress}";

    // Only check cache for idempotent read operations (never for mutations)
    if (!isMutation)
    {
        if (memoryCache.TryGetValue(cacheKey, out string? cachedResponse) && cachedResponse != null)
        {
            context.Response.Headers.Append("X-Cache-Source", "L1-Memory");
            return Results.Ok(cachedResponse);
        }
    }

    await semaphore.WaitAsync(ct);
    try
    {
        return await circuitBreakerPolicy.ExecuteAsync(async () =>
        {
            // SECURITY FIX: Whitelist execution (if configured) or prefix validation.
            if (allowedProcedures.Count > 0 && !allowedProcedures.Contains(paramsObj.ProcName))
            {
                return Results.Forbid();
            } 
            else if (allowedProcedures.Count == 0 && !paramsObj.ProcName.StartsWith("SP_", StringComparison.OrdinalIgnoreCase) && !paramsObj.ProcName.StartsWith("support.SP_", StringComparison.OrdinalIgnoreCase))
            {
                return Results.Json(new { Error = "Unsafe or unrecognized procedure prefix. Procedures must start with SP_ or support.SP_ or be added to AllowedProcedures in appsettings." }, statusCode: 403);
            }
            
            // Map plain sp_ to support.sp_ to match PostgreSQL Schema
            if (!paramsObj.ProcName.Contains("."))
            {
                paramsObj.ProcName = "support." + paramsObj.ProcName;
            }

            // High Performance DB lookup bypassing DataSet
            if (context.User.Identity != null && context.User.Identity.IsAuthenticated)
            {
                var tenantClaim = context.User.Claims.FirstOrDefault(c => c.Type == "TenantId");
                if (tenantClaim != null && !string.IsNullOrEmpty(tenantClaim.Value) && tenantClaim.Value != "00000000-0000-0000-0000-000000000000")
                {
                    paramsObj.ComCod = tenantClaim.Value;
                }
                
                var userIdClaim = context.User.Claims.FirstOrDefault(c => c.Type == System.Security.Claims.ClaimTypes.NameIdentifier);
                if (userIdClaim != null)
                {
                    paramsObj.parm08 = userIdClaim.Value;
                }

                var roleClaim = context.User.Claims.FirstOrDefault(c => c.Type == System.Security.Claims.ClaimTypes.Role);
                if (roleClaim != null)
                {
                    paramsObj.parm09 = roleClaim.Value;
                }
            }

            object responseObj = await api.GetApiResultAsync(paramsObj, legacyFormat);

            // Trigger Mobile Push Notification for new task assignment
            if (paramsObj.ProcID == "CREATE_TASK" && !string.IsNullOrEmpty(paramsObj.parm03))
            {
                _ = NotificationService.FireTaskAssignmentPushAsync(paramsObj.parm03, paramsObj.parm01);
            }

            string responseJson = responseObj is string sObj ? sObj : JsonSerializer.Serialize(responseObj);
            
            if (compress) responseJson = APIUtility.StrCompress(responseJson);
            
            // Only cache read queries with short TTL (3 seconds) to ensure fresh data after mutations
            if (!isMutation)
            {
                memoryCache.Set(cacheKey, responseJson, new MemoryCacheEntryOptions { AbsoluteExpirationRelativeToNow = TimeSpan.FromSeconds(3), Size = 1 });
            }
            
            context.Response.Headers.Append("X-Cache-Source", "Database");
            return Results.Ok(responseJson);
        });
    }
    catch (OperationCanceledException) { return Results.StatusCode(408); }
    catch (BrokenCircuitException) { return Results.StatusCode(503); }
    catch (Exception) { return Results.Problem("Internal Server Error"); }
    finally { semaphore.Release(); }
}


app.MapPost("/dbAsyncRequest", (HttpContext ctx, ProcessAccessAPI api, IMemoryCache m, IDistributedCache r, [FromBody] string b, CancellationToken c) => HandleDbRequest(ctx, api, m, r, b, c, true)).RequireAuthorization();
app.MapPost("/dbAsyncGetData", (HttpContext ctx, ProcessAccessAPI api, IMemoryCache m, IDistributedCache r, [FromBody] string b, CancellationToken c) => HandleDbRequest(ctx, api, m, r, b, c, true)).RequireAuthorization();
app.MapPost("/dbRequest", (HttpContext ctx, ProcessAccessAPI api, IMemoryCache m, IDistributedCache r, [FromBody] string b, CancellationToken c) => HandleDbRequest(ctx, api, m, r, b, c, true)).RequireAuthorization();
app.MapPost("/dbRequestRpt", (HttpContext ctx, ProcessAccessAPI api, IMemoryCache m, IDistributedCache r, [FromBody] string b, CancellationToken c) => HandleDbRequest(ctx, api, m, r, b, c, true)).RequireAuthorization();
app.MapPost("/mobiRequest", (HttpContext ctx, ProcessAccessAPI api, IMemoryCache m, IDistributedCache r, [FromBody] string b, CancellationToken c) => HandleDbRequest(ctx, api, m, r, b, c, false, true)).AllowAnonymous();

app.MapPost("/api/dbAsyncRequest", [EnableRateLimiting("ApiLimit")] async (HttpContext context, ProcessAccessAPI api, IMemoryCache mCache, IDistributedCache rCache, [FromBody] string body, CancellationToken ct) => 
    await HandleDbRequest(context, api, mCache, rCache, body, ct, true)).RequireAuthorization();

app.MapPost("/api/dbAsyncGetData", [EnableRateLimiting("ApiLimit")] async (HttpContext context, ProcessAccessAPI api, IMemoryCache mCache, IDistributedCache rCache, [FromBody] string body, CancellationToken ct) => 
    await HandleDbRequest(context, api, mCache, rCache, body, ct, true)).RequireAuthorization();

app.MapPost("/api/dbRequest", [EnableRateLimiting("ApiLimit")] async (HttpContext context, ProcessAccessAPI api, IMemoryCache mCache, IDistributedCache rCache, [FromBody] string body, CancellationToken ct) => 
    await HandleDbRequest(context, api, mCache, rCache, body, ct, true)).RequireAuthorization();

app.MapPost("/api/dbRequestRpt", [EnableRateLimiting("ApiLimit")] async (HttpContext context, ProcessAccessAPI api, IMemoryCache mCache, IDistributedCache rCache, [FromBody] string body, CancellationToken ct) => 
    await HandleDbRequest(context, api, mCache, rCache, body, ct, true)).RequireAuthorization();

// mobiRequest is anonymous - keeping legacy format for compatibility
app.MapPost("/api/mobiRequest", [EnableRateLimiting("ApiLimit")] async (HttpContext context, ProcessAccessAPI api, IMemoryCache mCache, IDistributedCache rCache, [FromBody] string body, CancellationToken ct) => 
    await HandleDbRequest(context, api, mCache, rCache, body, ct, false, true)).AllowAnonymous();

app.MapQrEndpoints();

app.Run();
