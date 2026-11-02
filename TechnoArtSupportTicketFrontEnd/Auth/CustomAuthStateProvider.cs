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

        public CustomAuthStateProvider(ProtectedLocalStorage localStorage)
        {
            _localStorage = localStorage;
        }

        public override async Task<AuthenticationState> GetAuthenticationStateAsync()
        {
            try
            {
                Console.WriteLine("[AUTH-DEBUG] GetAuthenticationStateAsync invoked");
                var userSessionResult = await _localStorage.GetAsync<string>("userToken");
                var userToken = userSessionResult.Success ? userSessionResult.Value : null;
                Console.WriteLine($"[AUTH-DEBUG] Success: {userSessionResult.Success}, HasToken: {!string.IsNullOrEmpty(userToken)}");

                if (string.IsNullOrWhiteSpace(userToken))
                    return new AuthenticationState(_anonymous);

                var claims = ParseClaimsFromJwt(userToken);
                var claimsIdentity = new ClaimsIdentity(claims, "jwtAuth");
                var claimsPrincipal = new ClaimsPrincipal(claimsIdentity);
                return new AuthenticationState(claimsPrincipal);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[AUTH-DEBUG] Exception: {ex.Message}");
                return new AuthenticationState(_anonymous);
            }
        }

        public async Task MarkUserAsAuthenticated(string token)
        {
            await _localStorage.SetAsync("userToken", token);
            var claims = ParseClaimsFromJwt(token);
            var claimsIdentity = new ClaimsIdentity(claims, "jwtAuth");
            var claimsPrincipal = new ClaimsPrincipal(claimsIdentity);
            NotifyAuthenticationStateChanged(Task.FromResult(new AuthenticationState(claimsPrincipal)));
        }

        public async Task MarkUserAsLoggedOut()
        {
            await _localStorage.DeleteAsync("userToken");
            NotifyAuthenticationStateChanged(Task.FromResult(new AuthenticationState(_anonymous)));
        }

        private IEnumerable<Claim> ParseClaimsFromJwt(string jwt)
        {
            var payload = jwt.Split('.')[1];
            var jsonBytes = ParseBase64WithoutPadding(payload);
            var keyValuePairs = JsonSerializer.Deserialize<Dictionary<string, object>>(jsonBytes);
            var claims = new List<Claim>();

            if (keyValuePairs != null)
            {
                foreach (var kvp in keyValuePairs)
                {
                    // Map JWT standard claims back to .NET Claims
                    if (kvp.Key == "unique_name" || kvp.Key == "name")
                        claims.Add(new Claim(ClaimTypes.Name, kvp.Value.ToString()!));
                    else if (kvp.Key == "role" || kvp.Key == "http://schemas.microsoft.com/ws/2008/06/identity/claims/role")
                        claims.Add(new Claim(ClaimTypes.Role, kvp.Value.ToString()!));
                    else if (kvp.Key == "nameid" || kvp.Key == "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier")
                        claims.Add(new Claim(ClaimTypes.NameIdentifier, kvp.Value.ToString()!));
                    else
                        claims.Add(new Claim(kvp.Key, kvp.Value.ToString()!));
                }
            }
            return claims;
        }

        private byte[] ParseBase64WithoutPadding(string base64)
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
