using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using System.Collections.Concurrent;

namespace TechnoArtSupprtAPI
{
    public static class QrLoginModule
    {
        // Thread-safe dictionary to maintain QR session state
        // Key: SessionId (QR Code data), Value: Null (waiting) or JWT Token String (approved)
        private static readonly ConcurrentDictionary<string, string?> QrSessions = new();

        public static void MapQrEndpoints(this WebApplication app)
        {
            // 1. Web application calls this to get a new unique session ID
            app.MapGet("/api/qr/generate", () =>
            {
                var sessionId = Guid.NewGuid().ToString("N");
                QrSessions.TryAdd(sessionId, null); // Add session, token is unassigned

                // Auto-cleanup after 90 seconds to avoid memory leaks
                _ = Task.Run(async () =>
                {
                    await Task.Delay(TimeSpan.FromSeconds(90));
                    QrSessions.TryRemove(sessionId, out _);
                });

                return Results.Ok(new { sessionId });
            }).AllowAnonymous();

            // 2. Web application constantly polls this to see if Mobile App approved it
            app.MapGet("/api/qr/poll/{sessionId}", (string sessionId) =>
            {
                if (!QrSessions.TryGetValue(sessionId, out var userToken))
                {
                    return Results.NotFound(new { status = "EXPIRED_OR_INVALID" });
                }

                if (!string.IsNullOrEmpty(userToken))
                {
                    // Approved by mobile app! Let's consume and remove it for security
                    QrSessions.TryRemove(sessionId, out _);
                    return Results.Ok(new { status = "APPROVED", token = userToken });
                }

                return Results.Ok(new { status = "WAITING" });
            }).AllowAnonymous();

            // 3. Mobile application calls this POST after scanning the QR code
            app.MapPost("/api/qr/approve", async ([FromBody] QrApproveRequest req, HttpContext context, IConfiguration config) =>
            {
                if (string.IsNullOrEmpty(req.SessionId) || string.IsNullOrEmpty(req.MobileToken))
                    return Results.BadRequest(new { error = "Invalid Payload" });

                if (QrSessions.ContainsKey(req.SessionId))
                {
                    // Check if MobileToken (FCM Token) matches any user
                    string connStr = config.GetConnectionString("PostgresConnStr") ?? "";
                    string userId = "";
                    string username = "";
                    string role = "ClientUser";
                    string tenantId = "";

                    bool foundUser = false;
                    try
                    {
                        using var conn = new Npgsql.NpgsqlConnection(connStr);
                        await conn.OpenAsync();
                        using var cmd = new Npgsql.NpgsqlCommand(@"
                            SELECT u.user_id, u.username, r.role_id, u.tenant_id 
                            FROM support.user_fcm_tokens f
                            JOIN auth.users u ON f.user_id = u.user_id
                            JOIN auth.user_roles r ON u.user_id = r.user_id
                            WHERE f.fcm_token = @fcm", conn);
                        cmd.Parameters.AddWithValue("fcm", req.MobileToken);
                        
                        using var reader = await cmd.ExecuteReaderAsync();
                        if (await reader.ReadAsync())
                        {
                            userId = reader.GetGuid(0).ToString();
                            username = reader.GetString(1);
                            role = reader.GetString(2);
                            tenantId = reader.IsDBNull(3) ? "" : reader.GetGuid(3).ToString();
                            foundUser = true;
                        }
                    }
                    catch (Exception ex)
                    {
                        return Results.Problem("Database Error: " + ex.Message);
                    }

                    if (foundUser)
                    {
                        // Generate Web JWT Token for this matched user
                        var webJwt = ApiConst.CreateTokenForDbUser(userId, username, role, tenantId);
                        
                        // Mark session as approved with the generated token
                        QrSessions[req.SessionId] = webJwt.tokenstr;
                        return Results.Ok(new { success = true });
                    }
                    else
                    {
                        return Results.Unauthorized();
                    }
                }

                return Results.NotFound(new { error = "Session expired or invalid" });
            }).AllowAnonymous();
        }
    }

    public class QrApproveRequest
    {
        public string SessionId { get; set; } = "";
        public string MobileToken { get; set; } = "";
    }
}
