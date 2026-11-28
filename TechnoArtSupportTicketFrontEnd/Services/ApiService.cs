using System.Text;
using System.Text.Json;
using System.IO.Compression;
using Microsoft.AspNetCore.Components.Server.ProtectedBrowserStorage;
using System.Net.Http.Headers;
using System.Net.Http.Json;

namespace TechnoArtSupportTicketFrontEnd.Services
{
    public class APIDataAccParms
    {
        public string ComCod { get; set; } = "";
        public string ProcName { get; set; } = "sp_ticket_operations"; 
        public string ProcID { get; set; } = "";
        public string parmJson1 { get; set; } = "";
        public string parmJson2 { get; set; } = "";
        public byte[]? parmBin01 { get; set; }
        public string parm01 { get; set; } = "";
        public string parm02 { get; set; } = "";
        public string parm03 { get; set; } = "";
        public string parm04 { get; set; } = "";
        public string parm05 { get; set; } = "";
        public string parm06 { get; set; } = "";
        public string parm07 { get; set; } = "";
        public string parm08 { get; set; } = "";
        public string parm09 { get; set; } = "";
        public string parm10 { get; set; } = "";
        public string Desc01 { get; set; } = "";
        public string Desc02 { get; set; } = "";
        public string Desc03 { get; set; } = "";
        public string Desc04 { get; set; } = "";
        public string Desc05 { get; set; } = "";
    }

    public class ApiService
    {
        private readonly HttpClient _http;
        private readonly ProtectedSessionStorage _sessionStorage;
        private readonly ProtectedLocalStorage? _localStorage;

        private string? _cachedToken;
        private bool _tokenLoaded = false;

        public ApiService(HttpClient http, ProtectedSessionStorage sessionStorage, ProtectedLocalStorage? localStorage = null)
        {
            _http = http;
            _sessionStorage = sessionStorage;
            _localStorage = localStorage;
        }

        public void SetToken(string? token)
        {
            _cachedToken = token;
        }

        public void ClearToken()
        {
            _cachedToken = null;
        }

        public async Task<JsonElement?> FetchDataAsync(APIDataAccParms requestParams, string? bearerToken = null)
        {
            try
            {
                // 1. JWT Implementation - attach token to header
                var effectiveToken = !string.IsNullOrWhiteSpace(bearerToken) ? bearerToken : _cachedToken;

                if (string.IsNullOrWhiteSpace(effectiveToken))
                {
                    try
                    {
                        var sessionResult = await _sessionStorage.GetAsync<string>("userToken");
                        if (sessionResult.Success && !string.IsNullOrWhiteSpace(sessionResult.Value))
                        {
                            effectiveToken = sessionResult.Value;
                            _cachedToken = effectiveToken;
                        }
                    }
                    catch { }
                }
                
                // 2. Prepare payload (Base64 encoded JSON string exactly as API expects)
                var jsonRequest = JsonSerializer.Serialize(requestParams);
                var base64Request = Convert.ToBase64String(Encoding.UTF8.GetBytes(jsonRequest));

                // 3. Post to specific API endpoint using HttpRequestMessage to prevent concurrent header issues
                var requestMessage = new HttpRequestMessage(HttpMethod.Post, "api/dbAsyncRequest")
                {
                    Content = JsonContent.Create(base64Request)
                };

                if (!string.IsNullOrWhiteSpace(effectiveToken))
                {
                    requestMessage.Headers.Authorization = new AuthenticationHeaderValue("Bearer", effectiveToken);
                }

                var response = await _http.SendAsync(requestMessage);

                if (!response.IsSuccessStatusCode)
                {
                    var errContent = await response.Content.ReadAsStringAsync();
                    Console.WriteLine($"[API Error {response.StatusCode}]: {errContent}");
                    
                    string serverDetail = "";
                    try
                    {
                        using var errDoc = JsonDocument.Parse(errContent);
                        var rootErr = errDoc.RootElement;
                        if (rootErr.TryGetProperty("detail", out var dt) && !string.IsNullOrEmpty(dt.GetString()))
                            serverDetail = dt.GetString()!;
                        else if (rootErr.TryGetProperty("title", out var tt) && !string.IsNullOrEmpty(tt.GetString()))
                            serverDetail = tt.GetString()!;
                        else if (rootErr.TryGetProperty("error", out var er) && !string.IsNullOrEmpty(er.GetString()))
                            serverDetail = er.GetString()!;
                        else if (rootErr.TryGetProperty("message", out var msg) && !string.IsNullOrEmpty(msg.GetString()))
                            serverDetail = msg.GetString()!;
                        else
                            serverDetail = errContent;
                    }
                    catch
                    {
                        serverDetail = string.IsNullOrWhiteSpace(errContent) ? response.ReasonPhrase ?? "Internal Server Error" : errContent;
                    }

                    // Return normalized error object with explicit "error" message so frontend surfaces it directly
                    var normalizedError = JsonSerializer.Serialize(new
                    {
                        success = false,
                        error = $"Live API Server Error ({response.StatusCode}): {serverDetail}",
                        status = (int)response.StatusCode
                    });
                    using var normalizedDoc = JsonDocument.Parse(normalizedError);
                    return normalizedDoc.RootElement.Clone();
                }

                // 4. Read response
                var compressedResponseStr = await response.Content.ReadAsStringAsync();
                compressedResponseStr = compressedResponseStr.Trim('"');

                // 5. Decompress
                var decompressedJson = DecompressString(compressedResponseStr);
                if (string.IsNullOrWhiteSpace(decompressedJson))
                {
                    return null;
                }

                // 6. Parse and extract defensively
                var jsonOptions = new JsonDocumentOptions
                {
                    AllowTrailingCommas = true,
                    CommentHandling = JsonCommentHandling.Skip
                };

                JsonDocument? document = null;
                try
                {
                    document = JsonDocument.Parse(decompressedJson, jsonOptions);
                }
                catch (JsonException ex)
                {
                    Console.WriteLine($"[ApiService] Warning: Direct JsonDocument.Parse failed at byte {ex.BytePositionInLine}: {ex.Message}");

                    // Defensive repair for chunked or split JSON strings
                    var sanitized = decompressedJson.Trim();

                    // If double commas exist due to SQL row splitting: ",," -> ","
                    if (sanitized.Contains(",,"))
                    {
                        sanitized = sanitized.Replace(",,", ",");
                    }

                    // If starts with comma
                    if (sanitized.StartsWith(","))
                    {
                        sanitized = sanitized.TrimStart(',', ' ', '\r', '\n', '\t');
                    }

                    // If it is enclosed in an extra set of escaped quotes
                    if (sanitized.StartsWith("\"") && sanitized.EndsWith("\"") && sanitized.Length > 2)
                    {
                        try
                        {
                            sanitized = JsonSerializer.Deserialize<string>(sanitized) ?? sanitized;
                        }
                        catch { }
                    }

                    try
                    {
                        document = JsonDocument.Parse(sanitized, jsonOptions);
                    }
                    catch (Exception ex2)
                    {
                        Console.WriteLine($"[ApiService] Sanitized parse attempt failed: {ex2.Message}");
                    }
                }

                if (document == null)
                {
                    Console.WriteLine($"[ApiService] Unable to parse response JSON: {decompressedJson.Substring(0, Math.Min(300, decompressedJson.Length))}");
                    return null;
                }

                using (document)
                {
                    var root = document.RootElement;
                    return ExtractData(root).Clone();
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Exception in FetchDataAsync: {ex.Message}");
                return null;
            }
        }

        private JsonElement ExtractData(JsonElement root)
        {
            if (root.ValueKind == JsonValueKind.Array)
            {
                return UnwrapJsonChunks(root);
            }

            if (root.ValueKind == JsonValueKind.String)
            {
                var s = root.GetString()?.Trim();
                if (!string.IsNullOrEmpty(s) && ((s.StartsWith("[") && s.EndsWith("]")) || (s.StartsWith("{") && s.EndsWith("}"))))
                {
                    try
                    {
                        var doc = JsonDocument.Parse(s);
                        return ExtractData(doc.RootElement.Clone());
                    }
                    catch { }
                }
                return root;
            }

            if (root.ValueKind == JsonValueKind.Object)
            {
                // Check if root has a direct result_json string property
                if (root.TryGetProperty("result_json", out var rj) && rj.ValueKind == JsonValueKind.String)
                {
                    var s = rj.GetString()?.Trim();
                    if (!string.IsNullOrEmpty(s))
                    {
                        try
                        {
                            var doc = JsonDocument.Parse(s);
                            return ExtractData(doc.RootElement.Clone());
                        }
                        catch { }
                    }
                }

                // Check for Table, Table1, table, or dataset envelope array properties
                var envelopeNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
                {
                    "Table", "Table1", "Table2", "Table3", "data", "items", "rows", "results"
                };

                foreach (var prop in root.EnumerateObject())
                {
                    if (prop.Value.ValueKind == JsonValueKind.Array && envelopeNames.Contains(prop.Name))
                    {
                        return UnwrapJsonChunks(prop.Value);
                    }
                }
            }

            return root;
        }

        private JsonElement UnwrapJsonChunks(JsonElement arr)
        {
            if (arr.ValueKind != JsonValueKind.Array || arr.GetArrayLength() == 0)
            {
                return arr;
            }

            var firstRow = arr[0];
            if (firstRow.ValueKind == JsonValueKind.Object)
            {
                // Safely find JSON column name without throwing InvalidOperationException on default struct
                string? jsonColName = null;
                foreach (var prop in firstRow.EnumerateObject())
                {
                    if ((prop.Name.StartsWith("JSON_", StringComparison.OrdinalIgnoreCase) ||
                         prop.Name.Equals("result_json", StringComparison.OrdinalIgnoreCase) ||
                         prop.Name.Equals("Column1", StringComparison.OrdinalIgnoreCase)) &&
                        prop.Value.ValueKind == JsonValueKind.String)
                    {
                        jsonColName = prop.Name;
                        break;
                    }
                }

                if (!string.IsNullOrEmpty(jsonColName))
                {
                    var sb = new StringBuilder();
                    foreach (var row in arr.EnumerateArray())
                    {
                        if (row.ValueKind == JsonValueKind.Object &&
                            row.TryGetProperty(jsonColName, out var chunk) &&
                            chunk.ValueKind == JsonValueKind.String)
                        {
                            sb.Append(chunk.GetString());
                        }
                    }

                    var combined = sb.ToString().Trim();
                    if (!string.IsNullOrEmpty(combined) &&
                        ((combined.StartsWith("[") && combined.EndsWith("]")) ||
                         (combined.StartsWith("{") && combined.EndsWith("}"))))
                    {
                        try
                        {
                            var doc = JsonDocument.Parse(combined);
                            return ExtractData(doc.RootElement.Clone());
                        }
                        catch { }
                    }
                }

                // 2. Check if single column row contains embedded JSON
                var objProps = firstRow.EnumerateObject().ToList();
                if (objProps.Count == 1 && objProps[0].Value.ValueKind == JsonValueKind.String)
                {
                    var singleStr = objProps[0].Value.GetString()?.Trim();
                    if (!string.IsNullOrEmpty(singleStr) &&
                        ((singleStr.StartsWith("[") && singleStr.EndsWith("]")) ||
                         (singleStr.StartsWith("{") && singleStr.EndsWith("}"))))
                    {
                        try
                        {
                            var doc = JsonDocument.Parse(singleStr);
                            return ExtractData(doc.RootElement.Clone());
                        }
                        catch { }
                    }
                }
            }

            // 3. Regular data table array (e.g. [{"id": "1", "name": "Dhaka"}, ...])
            return arr;
        }

        private string DecompressString(string compressedBase64)
        {
            try
            {
                var bytes = Convert.FromBase64String(compressedBase64);
                using var msi = new MemoryStream(bytes);
                using var gs = new GZipStream(msi, CompressionMode.Decompress);
                using var mso = new MemoryStream();
                gs.CopyTo(mso);
                var decompressedBytes = mso.ToArray();

                string textUnicode = Encoding.Unicode.GetString(decompressedBytes);
                if (textUnicode.TrimStart().StartsWith("{") || textUnicode.TrimStart().StartsWith("["))
                {
                    return textUnicode;
                }

                string textUtf8 = Encoding.UTF8.GetString(decompressedBytes);
                if (textUtf8.TrimStart().StartsWith("{") || textUtf8.TrimStart().StartsWith("["))
                {
                    return textUtf8;
                }

                return textUnicode;
            }
            catch
            {
                return compressedBase64; // Return as-is if it wasn't compressed
            }
        }
    }
}
