using Microsoft.Data.SqlClient;
using Microsoft.IdentityModel.Tokens;
using Npgsql;
using NpgsqlTypes;
using System.Data;
using System.IdentityModel.Tokens.Jwt;
using System.IO.Compression;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace TechnoArtSupprtAPI
{
    // =====================================================================
    // Database provider enum — driven by appsettings "DatabaseType" value
    // =====================================================================
    public enum DbProvider { MSSQL, PostgreSQL }

    // =====================================================================
    // ProcessAccessAPI — top-level service injected in endpoints
    // =====================================================================
    public class ProcessAccessAPI
    {
        private readonly APIDataAccess _dataAccess;

        public ProcessAccessAPI(IConfiguration configuration)
        {
            var dbType = configuration.GetValue<string>("DatabaseType") ?? "PostgreSQL";
            DbProvider provider = dbType.Equals("MSSQL", StringComparison.OrdinalIgnoreCase)
                ? DbProvider.MSSQL
                : DbProvider.PostgreSQL;

            string connStr = "";
            string fallbackConnStr = "";

            if (provider == DbProvider.MSSQL)
            {
                connStr = DbInitHelper.ResolvedMssqlConnectionString
                          ?? configuration.GetConnectionString("MssqlConnStr")
                          ?? "";
                fallbackConnStr = configuration.GetConnectionString("MssqlConnStr_sa") ?? "";
            }
            else
            {
                connStr = configuration.GetConnectionString("PostgresConnStr") ?? "";
            }

            _dataAccess = new APIDataAccess(connStr, provider, fallbackConnStr);
        }

        public async Task<object> GetApiResultAsync(APIDataAccParms pap1, bool legacyFormat = false)
        {
            try
            {
                return await _dataAccess.GetApiResultAsync(pap1, legacyFormat);
            }
            catch (Exception ex)
            {
                var errObj = new Dictionary<string, List<Dictionary<string, object>>>();
                var errorRow = new Dictionary<string, object>
                {
                    { "errornumber",   0 },
                    { "errorseverity", 0 },
                    { "errorstate",    0 },
                    { "errorprocedure", 0 },
                    { "errorline",     0 },
                    { "errormessage",  $"[{ex.Source}] {ex.Message}" }
                };
                errObj["ErrorTable"] = new List<Dictionary<string, object>> { errorRow };

                if (legacyFormat)
                    return new List<List<Dictionary<string, object>>> { errObj["ErrorTable"] };

                return errObj;
            }
        }
    }

    // =====================================================================
    // APIDataAccParms — unified parameter bag for all operations
    // =====================================================================
    [Serializable]
    public class APIDataAccParms
    {
        public string ComCod    { get; set; } = "";
        public string ProcName  { get; set; } = "";
        public string ProcID    { get; set; } = "";
        public string parmJson1 { get; set; } = "";
        public string parmJson2 { get; set; } = "";
        public byte[]? parmBin01 { get; set; }
        public string parm01    { get; set; } = "";
        public string parm02    { get; set; } = "";
        public string parm03    { get; set; } = "";
        public string parm04    { get; set; } = "";
        public string parm05    { get; set; } = "";
        public string parm06    { get; set; } = "";
        public string parm07    { get; set; } = "";
        public string parm08    { get; set; } = "";
        public string parm09    { get; set; } = "";
        public string parm10    { get; set; } = "";
    }

    // =====================================================================
    // APIDataAccess — dual-mode database access (MSSQL / PostgreSQL)
    // =====================================================================
    public class APIDataAccess
    {
        private string              _connectionString;
        private readonly DbProvider _provider;
        private readonly string?    _fallbackConnectionString;

        // Fixed stored-procedure names
        private const string MssqlProcName  = "support.SP_TICKET_OPERATIONS";
        private const string PgFunctionName = "support.sp_ticket_operations";

        public APIDataAccess(string connectionString, DbProvider provider, string? fallbackConnectionString = null)
        {
            _connectionString         = connectionString;
            _provider                 = provider;
            _fallbackConnectionString = fallbackConnectionString;
        }

        public Task<object> GetApiResultAsync(APIDataAccParms pap1, bool legacyFormat)
        {
            return _provider == DbProvider.MSSQL
                ? ExecuteMssqlAsync(pap1, legacyFormat)
                : ExecutePostgresAsync(pap1, legacyFormat);
        }

        // -----------------------------------------------------------------
        // MSSQL execution — calls EXEC support.SP_TICKET_OPERATIONS
        // -----------------------------------------------------------------
        private async Task<object> ExecuteMssqlAsync(APIDataAccParms p, bool legacyFormat)
        {
            // Resolve the proc name: ProcName override or fixed wrapper
            string procName = !string.IsNullOrWhiteSpace(p.ProcName)
                ? p.ProcName
                : MssqlProcName;

            SqlConnection conn;
            try
            {
                conn = new SqlConnection(_connectionString);
                await conn.OpenAsync();
            }
            catch (Exception) when (!string.IsNullOrWhiteSpace(_fallbackConnectionString) && _connectionString != _fallbackConnectionString)
            {
                conn = new SqlConnection(_fallbackConnectionString);
                await conn.OpenAsync();
                _connectionString = _fallbackConnectionString;
                DbInitHelper.ResolvedMssqlConnectionString = _fallbackConnectionString;
            }

            using (conn)
            {
                using var cmd = new SqlCommand(procName, conn)
                {
                    CommandType = CommandType.StoredProcedure,
                    CommandTimeout = 30
                };

                cmd.Parameters.Add("@p_ComCod", SqlDbType.NVarChar, 100).Value = p.ComCod ?? "";
                cmd.Parameters.Add("@p_ProcID", SqlDbType.NVarChar, 100).Value = p.ProcID ?? "";
                cmd.Parameters.Add("@p_Djson1", SqlDbType.NVarChar, -1).Value = string.IsNullOrEmpty(p.parmJson1) ? "{}" : p.parmJson1;
                cmd.Parameters.Add("@p_Djson2", SqlDbType.NVarChar, -1).Value = string.IsNullOrEmpty(p.parmJson2) ? "{}" : p.parmJson2;
                cmd.Parameters.Add("@p_Dbin01", SqlDbType.VarBinary, -1).Value = (object?)p.parmBin01 ?? DBNull.Value;
                cmd.Parameters.Add("@p_Desc01", SqlDbType.NVarChar, -1).Value = p.parm01 ?? "";
                cmd.Parameters.Add("@p_Desc02", SqlDbType.NVarChar, -1).Value = p.parm02 ?? "";
                cmd.Parameters.Add("@p_Desc03", SqlDbType.NVarChar, -1).Value = p.parm03 ?? "";
                cmd.Parameters.Add("@p_Desc04", SqlDbType.NVarChar, -1).Value = p.parm04 ?? "";
                cmd.Parameters.Add("@p_Desc05", SqlDbType.NVarChar, -1).Value = p.parm05 ?? "";
                cmd.Parameters.Add("@p_Desc06", SqlDbType.NVarChar, -1).Value = p.parm06 ?? "";
                cmd.Parameters.Add("@p_Desc07", SqlDbType.NVarChar, -1).Value = p.parm07 ?? "";
                cmd.Parameters.Add("@p_Desc08", SqlDbType.NVarChar, -1).Value = p.parm08 ?? "";
                cmd.Parameters.Add("@p_Desc09", SqlDbType.NVarChar, -1).Value = p.parm09 ?? "";
                cmd.Parameters.Add("@p_Desc10", SqlDbType.NVarChar, -1).Value = p.parm10 ?? "";

                // MSSQL SP returns a result_json column per row
                var resultsData = new List<string>();
                using (var reader = await cmd.ExecuteReaderAsync())
                {
                    while (await reader.ReadAsync())
                    {
                        var val = reader.IsDBNull(0) ? null : reader.GetString(0);
                        if (val != null) resultsData.Add(val);
                    }
                }

                return BuildResult(resultsData, legacyFormat);
            }
        }

        // -----------------------------------------------------------------
        // PostgreSQL execution — calls SELECT * FROM support.sp_ticket_operations(...)
        // -----------------------------------------------------------------
        private async Task<object> ExecutePostgresAsync(APIDataAccParms p, bool legacyFormat)
        {
            string procName = !string.IsNullOrWhiteSpace(p.ProcName)
                ? p.ProcName
                : PgFunctionName;

            // Map plain SP_ prefix to support.sp_
            if (!procName.Contains("."))
                procName = "support." + procName;

            string sql = $"SELECT * FROM {procName}(" +
                         "@p_ComCod, @p_ProcID, @p_Djson1::jsonb, @p_Djson2::jsonb, @p_Dbin01," +
                         "@p_Desc01, @p_Desc02, @p_Desc03, @p_Desc04, @p_Desc05," +
                         "@p_Desc06, @p_Desc07, @p_Desc08, @p_Desc09, @p_Desc10)";

            using var conn = new NpgsqlConnection(_connectionString);
            await conn.OpenAsync();

            using var cmd = new NpgsqlCommand(sql, conn) { CommandTimeout = 30 };

            cmd.Parameters.AddWithValue("p_ComCod",  NpgsqlDbType.Varchar, p.ComCod  ?? "");
            cmd.Parameters.AddWithValue("p_ProcID",  NpgsqlDbType.Varchar, p.ProcID  ?? "");
            cmd.Parameters.AddWithValue("p_Djson1",  NpgsqlDbType.Text,    string.IsNullOrEmpty(p.parmJson1) ? "{}" : p.parmJson1);
            cmd.Parameters.AddWithValue("p_Djson2",  NpgsqlDbType.Text,    string.IsNullOrEmpty(p.parmJson2) ? "{}" : p.parmJson2);
            cmd.Parameters.AddWithValue("p_Dbin01",  NpgsqlDbType.Bytea,   (object?)p.parmBin01 ?? DBNull.Value);
            cmd.Parameters.AddWithValue("p_Desc01",  NpgsqlDbType.Varchar, p.parm01  ?? "");
            cmd.Parameters.AddWithValue("p_Desc02",  NpgsqlDbType.Varchar, p.parm02  ?? "");
            cmd.Parameters.AddWithValue("p_Desc03",  NpgsqlDbType.Varchar, p.parm03  ?? "");
            cmd.Parameters.AddWithValue("p_Desc04",  NpgsqlDbType.Varchar, p.parm04  ?? "");
            cmd.Parameters.AddWithValue("p_Desc05",  NpgsqlDbType.Varchar, p.parm05  ?? "");
            cmd.Parameters.AddWithValue("p_Desc06",  NpgsqlDbType.Varchar, p.parm06  ?? "");
            cmd.Parameters.AddWithValue("p_Desc07",  NpgsqlDbType.Varchar, p.parm07  ?? "");
            cmd.Parameters.AddWithValue("p_Desc08",  NpgsqlDbType.Varchar, p.parm08  ?? "");
            cmd.Parameters.AddWithValue("p_Desc09",  NpgsqlDbType.Varchar, p.parm09  ?? "");
            cmd.Parameters.AddWithValue("p_Desc10",  NpgsqlDbType.Varchar, p.parm10  ?? "");

            var resultsData = new List<string>();
            using (var reader = await cmd.ExecuteReaderAsync())
            {
                while (await reader.ReadAsync())
                    resultsData.Add(reader.GetString(0));
            }

            return BuildResult(resultsData, legacyFormat);
        }

        // -----------------------------------------------------------------
        // Shared result builder
        // -----------------------------------------------------------------
        private static object BuildResult(List<string> rows, bool legacyFormat)
        {
            if (legacyFormat)
            {
                var legacyResult = new List<Dictionary<string, object?>>();
                foreach (var raw in rows)
                {
                    try
                    {
                        var el = JsonDocument.Parse(raw).RootElement;
                        var dict = new Dictionary<string, object?>();
                        if (el.ValueKind == JsonValueKind.Object)
                            foreach (var prop in el.EnumerateObject())
                                dict[prop.Name] = prop.Value.ToString();
                        legacyResult.Add(dict);
                    }
                    catch { }
                }
                return new List<List<Dictionary<string, object?>>> { legacyResult };
            }

            if (rows.Count == 0)           return "[]";
            if (rows.Count == 1)           return rows[0];
            return "[" + string.Join(",", rows) + "]";
        }
    }

    // =====================================================================
    // ApiConst — JWT helpers
    // =====================================================================
    public class ApiConst
    {
        public static string Issuer   { get; set; } = "user001";
        public static string Audience { get; set; } = "McMiniAPIUser";
        public static string Key      { get; set; } = "28216481291932476_SECURE_JWT_KEY_32";

        public static void Initialize(IConfiguration configuration)
        {
            var section = configuration.GetSection("JwtSettings");
            Issuer   = section["Issuer"]   ?? Issuer;
            Audience = section["Audience"] ?? Audience;
            Key      = section["Key"]      ?? Key;
        }

        public static JwtTokenInfo CreateToken(JwtTokenUser model)
        {
            JwtTokenInfo tokeninf = new();
            try
            {
                if (model.UserId == "user001" && model.Password == "12345678")
                    tokeninf = BuildToken(model.UserId ?? "", model.UserId ?? "", "SuperAdmin", "00000000-0000-0000-0000-000000000000", 2);
            }
            catch (Exception ex) { tokeninf.tokenmsg = ex.Message; }
            return tokeninf;
        }

        public static JwtTokenInfo CreateTokenForDbUser(string userId, string username, string roleName, string tenantId)
        {
            try   { return BuildToken(userId, username, roleName, tenantId, 8); }
            catch (Exception ex) { return new JwtTokenInfo { tokenmsg = ex.Message }; }
        }

        private static JwtTokenInfo BuildToken(string userId, string username, string role, string tenantId, int hours)
        {
            var claims = new[]
            {
                new System.Security.Claims.Claim(System.Security.Claims.ClaimTypes.Name,           username),
                new System.Security.Claims.Claim(System.Security.Claims.ClaimTypes.NameIdentifier, userId),
                new System.Security.Claims.Claim(System.Security.Claims.ClaimTypes.Role,           role),
                new System.Security.Claims.Claim("TenantId", tenantId)
            };
            var secKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(Key));
            var creds  = new SigningCredentials(secKey, SecurityAlgorithms.HmacSha256);
            var expiry = DateTime.UtcNow.AddHours(hours);
            var token  = new JwtSecurityToken(Issuer, Audience, claims, expires: expiry, signingCredentials: creds);

            return new JwtTokenInfo
            {
                istokenstr = true,
                tokenstr   = new JwtSecurityTokenHandler().WriteToken(token),
                tokenmsg   = "Token created successfully",
                createtime = DateTime.UtcNow,
                expirytime  = expiry
            };
        }
    }

    // =====================================================================
    // DTOs
    // =====================================================================
    public class JwtTokenUser
    {
        [JsonPropertyName("userId")]   public string? UserId    { get; set; } = "NOUSER";
        [JsonPropertyName("password")] public string? Password  { get; set; } = "";
        [JsonPropertyName("roleName")] public string? RoleName  { get; set; } = "";
        [JsonPropertyName("expirhour")] public JsonElement Expirhour { get; set; }
    }

    public class LoginRequest
    {
        [JsonPropertyName("userId")]   public string? UserId   { get; set; }
        [JsonPropertyName("password")] public string? Password { get; set; }
        [JsonPropertyName("fcmToken")] public string? FcmToken { get; set; }
    }

    public class JwtTokenInfo
    {
        public bool     istokenstr { get; set; } = false;
        public string   tokenstr   { get; set; } = "Nothing";
        public DateTime createtime { get; set; } = DateTime.UtcNow;
        public DateTime expirytime  { get; set; } = DateTime.UtcNow;
        public string   tokenmsg   { get; set; } = "Failed to create token";
    }

    // =====================================================================
    // Utility
    // =====================================================================
    public static class APIUtility
    {
        public static string StrCompress(string s)
        {
            var bytes = Encoding.Unicode.GetBytes(s);
            using var mso = new MemoryStream();
            using (var gs = new GZipStream(mso, CompressionLevel.Fastest))
                gs.Write(bytes, 0, bytes.Length);
            return Convert.ToBase64String(mso.ToArray());
        }
    }
}
