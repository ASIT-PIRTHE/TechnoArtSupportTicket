using Microsoft.AspNetCore.Components.Authorization;
using Microsoft.AspNetCore.Components.Server.ProtectedBrowserStorage;
using System.Security.Claims;
using System.Text.Json;

namespace TechnoArtSupportTicketFrontEnd.Auth
{
    public class CustomAuthStateProvider : AuthenticationStateProvider
    {
        private readonly ProtectedLocalStorage _localStorage;
        private ClaimsPrincipal _anonymous = new ClaimsPrincipal(new ClaimsIdentity());
        private ClaimsPrincipal? _cachedPrincipal;

        public string? CurrentToken { get; private set; }

        public CustomAuthStateProvider(ProtectedLocalStorage localStorage)
        {
            _localStorage = localStorage;
        }

        public override async Task<AuthenticationState> GetAuthenticationStateAsync()
        {
            try
            {
                if (_cachedPrincipal != null && _cachedPrincipal.Identity?.IsAuthenticated == true)
                {
                    return new AuthenticationState(_cachedPrincipal);
                }

                string? userToken = null;
                try
                {
                    var userSessionResult = await _localStorage.GetAsync<string>("userToken");
                    userToken = userSessionResult.Success ? userSessionResult.Value : null;
                }
                catch
                {
                    // During prerender JavaScript interop is not ready. Return anonymous cleanly.
                    return new AuthenticationState(_anonymous);
                }

                if (string.IsNullOrWhiteSpace(userToken))
                    return new AuthenticationState(_anonymous);

                CurrentToken = userToken;

                var claims = ParseClaimsFromJwt(userToken);
                var claimsIdentity = new ClaimsIdentity(claims, "jwtAuth", ClaimTypes.Name, ClaimTypes.Role);
                _cachedPrincipal = new ClaimsPrincipal(claimsIdentity);
                return new AuthenticationState(_cachedPrincipal);
            }
            catch (Exception)
            {
                return new AuthenticationState(_anonymous);
            }
        }

        public async Task MarkUserAsAuthenticated(string token)
        {
            CurrentToken = token;
            try
            {
                await _localStorage.SetAsync("userToken", token);
            }
            catch { }

            var claims = ParseClaimsFromJwt(token);
            var claimsIdentity = new ClaimsIdentity(claims, "jwtAuth", ClaimTypes.Name, ClaimTypes.Role);
            _cachedPrincipal = new ClaimsPrincipal(claimsIdentity);
            NotifyAuthenticationStateChanged(Task.FromResult(new AuthenticationState(_cachedPrincipal)));
        }

        public async Task MarkUserAsLoggedOut()
        {
            _cachedPrincipal = null;
            CurrentToken = null;
            try
            {
                await _localStorage.DeleteAsync("userToken");
            }
            catch { }
            NotifyAuthenticationStateChanged(Task.FromResult(new AuthenticationState(_anonymous)));
        }

        public static IEnumerable<Claim> ParseClaimsFromJwt(string jwt)
        {
            var claims = new List<Claim>();
            try
            {
                var parts = jwt.Split('.');
                if (parts.Length < 2) return claims;
                var payload = parts[1];
                var jsonBytes = ParseBase64WithoutPadding(payload);
                using var doc = JsonDocument.Parse(jsonBytes);
                var root = doc.RootElement;

                foreach (var prop in root.EnumerateObject())
                {
                    var keyLower = prop.Name.ToLowerInvariant();
                    var isRoleKey = keyLower == "role" || keyLower == "roles" || 
                                    prop.Name == ClaimTypes.Role || 
                                    prop.Name == "http://schemas.microsoft.com/ws/2008/06/identity/claims/role";
                    var isNameKey = keyLower == "unique_name" || keyLower == "name" || prop.Name == ClaimTypes.Name;
                    var isIdKey = keyLower == "nameid" || keyLower == "id" || keyLower == "user_id" || keyLower == "userid" || 
                                  prop.Name == ClaimTypes.NameIdentifier || 
                                  prop.Name == "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier";

                    if (isRoleKey)
                    {
                        void AddRole(string roleStr)
                        {
                            if (string.IsNullOrWhiteSpace(roleStr)) return;
                            roleStr = roleStr.Trim();

                            string canonical = roleStr;
                            if (roleStr.Equals("superadmin", StringComparison.OrdinalIgnoreCase) || roleStr.Equals("admin", StringComparison.OrdinalIgnoreCase)) canonical = "SuperAdmin";
                            else if (roleStr.Equals("md", StringComparison.OrdinalIgnoreCase)) canonical = "MD";
                            else if (roleStr.Equals("hrmanager", StringComparison.OrdinalIgnoreCase) || roleStr.Equals("hr", StringComparison.OrdinalIgnoreCase)) canonical = "HRManager";
                            else if (roleStr.Equals("supportmanager", StringComparison.OrdinalIgnoreCase) || roleStr.Equals("support", StringComparison.OrdinalIgnoreCase)) canonical = "SupportManager";
                            else if (roleStr.Equals("projectmanager", StringComparison.OrdinalIgnoreCase) || roleStr.Equals("pm", StringComparison.OrdinalIgnoreCase)) canonical = "ProjectManager";
                            else if (roleStr.Equals("teammember", StringComparison.OrdinalIgnoreCase) || roleStr.Equals("engineer", StringComparison.OrdinalIgnoreCase) || roleStr.Equals("qa", StringComparison.OrdinalIgnoreCase)) canonical = "TeamMember";
                            else if (roleStr.Equals("accountsofficer", StringComparison.OrdinalIgnoreCase) || roleStr.Equals("accounts", StringComparison.OrdinalIgnoreCase)) canonical = "AccountsOfficer";
                            else if (roleStr.Equals("clientadmin", StringComparison.OrdinalIgnoreCase)) canonical = "ClientAdmin";
                            else if (roleStr.Equals("clientuser", StringComparison.OrdinalIgnoreCase)) canonical = "ClientUser";

                            claims.Add(new Claim(ClaimTypes.Role, canonical));
                            claims.Add(new Claim("role", canonical));
                            claims.Add(new Claim("Role", canonical));
                            if (!canonical.Equals(roleStr, StringComparison.OrdinalIgnoreCase))
                            {
                                claims.Add(new Claim(ClaimTypes.Role, roleStr));
                                claims.Add(new Claim("role", roleStr));
                            }
                        }

                        if (prop.Value.ValueKind == JsonValueKind.Array)
                        {
                            foreach (var item in prop.Value.EnumerateArray())
                            {
                                if (item.ValueKind == JsonValueKind.String)
                                    AddRole(item.GetString() ?? "");
                            }
                        }
                        else if (prop.Value.ValueKind == JsonValueKind.String)
                        {
                            AddRole(prop.Value.GetString() ?? "");
                        }
                    }
                    else if (isNameKey)
                    {
                        var val = prop.Value.GetString() ?? prop.Value.ToString();
                        claims.Add(new Claim(ClaimTypes.Name, val));
                        claims.Add(new Claim("name", val));
                    }
                    else if (isIdKey)
                    {
                        var val = prop.Value.GetString() ?? prop.Value.ToString();
                        claims.Add(new Claim(ClaimTypes.NameIdentifier, val));
                        claims.Add(new Claim("nameid", val));
                        claims.Add(new Claim("id", val));
                        claims.Add(new Claim("user_id", val));
                    }
                    else
                    {
                        var val = prop.Value.ValueKind == JsonValueKind.String ? prop.Value.GetString() ?? "" : prop.Value.ToString();
                        claims.Add(new Claim(prop.Name, val));
                    }
                }
            }
            catch { }

            return claims;
        }

        private static byte[] ParseBase64WithoutPadding(string base64)
        {
            switch (base64.Length % 4)
            {
                case 2: base64 += "=="; break;
                case 3: base64 += "="; break;
            }
            return Convert.FromBase64String(base64);
        }
    }
}
