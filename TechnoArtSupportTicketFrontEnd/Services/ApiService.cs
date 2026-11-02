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
    }

    public class ApiService
    {
        private readonly HttpClient _http;
        private readonly ProtectedLocalStorage _localStorage;

        private string? _cachedToken;
        private bool _tokenLoaded = false;

        public ApiService(HttpClient http, ProtectedLocalStorage localStorage)
        {
            _http = http;
            _localStorage = localStorage;
        }

        public async Task<JsonElement?> FetchDataAsync(APIDataAccParms requestParams)
        {
            try
            {
                // 1. JWT Implementation - attach token to header
                if (!_tokenLoaded)
                {
                    var tokenResult = await _localStorage.GetAsync<string>("userToken");
                    if (tokenResult.Success) _cachedToken = tokenResult.Value;
                    _tokenLoaded = true;
                }
                
                // 2. Prepare payload (Base64 encoded JSON string exactly as API expects)
                var jsonRequest = JsonSerializer.Serialize(requestParams);
                var base64Request = Convert.ToBase64String(Encoding.UTF8.GetBytes(jsonRequest));

                // 3. Post to specific API endpoint using HttpRequestMessage to prevent concurrent header issues
                var requestMessage = new HttpRequestMessage(HttpMethod.Post, "/api/dbAsyncRequest")
                {
                    Content = JsonContent.Create(base64Request)
                };

                if (!string.IsNullOrWhiteSpace(_cachedToken))
                {
                    requestMessage.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _cachedToken);
                }

                var response = await _http.SendAsync(requestMessage);

                if (!response.IsSuccessStatusCode)
                {
                    var errContent = await response.Content.ReadAsStringAsync();
                    Console.WriteLine($"API Error: {response.StatusCode} - {errContent}");
                    try
                    {
                        using var errDoc = JsonDocument.Parse(errContent);
                        return errDoc.RootElement.Clone();
                    }
                    catch
                    {
                        return null;
                    }
                }

                // 4. Read response
                var compressedResponseStr = await response.Content.ReadAsStringAsync();
                compressedResponseStr = compressedResponseStr.Trim('"');

                // 5. Decompress
                var decompressedJson = DecompressString(compressedResponseStr);
                
                // 6. Parse and extract directly
                using var document = JsonDocument.Parse(decompressedJson);
                var root = document.RootElement;
                
                // Allow fallback if backend is accidentally rendering legacy dataset still
                if (root.ValueKind == JsonValueKind.Object && root.TryGetProperty("Table", out var tableArray) && tableArray.GetArrayLength() > 0)
                {
                    var firstRow = tableArray[0];
                    if (firstRow.TryGetProperty("result_json", out var resultJsonStr))
                    {
                        var parsedString = resultJsonStr.GetString();
                        if (parsedString != null)
                             return JsonDocument.Parse(parsedString).RootElement.Clone();
                        return resultJsonStr.Clone();
                    }
                }
                
                // Otherwise natively process the Dapper PostgreSQL output
                return root.Clone();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Exception in FetchDataAsync: {ex.Message}");
                return null;
            }
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
                return Encoding.Unicode.GetString(mso.ToArray());
            }
            catch
            {
                return compressedBase64; // Return as-is if it wasn't compressed
            }
        }
    }
}
