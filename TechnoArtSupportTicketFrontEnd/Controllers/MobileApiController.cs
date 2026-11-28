using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using System.Text.Json;
using TechnoArtSupportTicketFrontEnd.Auth;
using TechnoArtSupportTicketFrontEnd.Services;

namespace TechnoArtSupportTicketFrontEnd.Controllers
{
    [ApiController]
    [Route("api/mobile")]
    [IgnoreAntiforgeryToken]
    public class MobileApiController : ControllerBase
    {
        private readonly ApiService _apiService;
        private readonly IHttpClientFactory _clientFactory;
        private readonly IConfiguration _config;
        private readonly IEmailService? _emailService;

        public MobileApiController(ApiService apiService, IHttpClientFactory clientFactory, IConfiguration config, IEmailService? emailService = null)
        {
            _apiService = apiService;
            _clientFactory = clientFactory;
            _config = config;
            _emailService = emailService;
        }

        // ====================================================================
        // HELPER: Extract Bearer Token & User Claims
        // ====================================================================
        private string? GetBearerToken()
        {
            var authHeader = Request.Headers["Authorization"].FirstOrDefault();
            if (!string.IsNullOrWhiteSpace(authHeader) && authHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
            {
                return authHeader.Substring("Bearer ".Length).Trim();
            }
            return null;
        }

        private (string UserId, string Username, string Role, string TenantId) GetUserContextFromToken(string token)
        {
            try
            {
                var claims = CustomAuthStateProvider.ParseClaimsFromJwt(token);
                var userId = claims.FirstOrDefault(c => c.Type == ClaimTypes.NameIdentifier || c.Type == "id" || c.Type == "user_id" || c.Type == "nameid")?.Value ?? "";
                var username = claims.FirstOrDefault(c => c.Type == ClaimTypes.Name || c.Type == "name" || c.Type == "unique_name")?.Value ?? "";
                var role = claims.FirstOrDefault(c => c.Type == ClaimTypes.Role || c.Type == "role" || c.Type == "Role")?.Value ?? "";
                var tenantId = claims.FirstOrDefault(c => c.Type == "tenant_id" || c.Type == "TenantId" || c.Type == "tenant")?.Value ?? "";
                return (userId, username, role, tenantId);
            }
            catch
            {
                return ("", "", "", "");
            }
        }

        private static double CalculateDistanceMeters(double lat1, double lon1, double lat2, double lon2)
        {
            const double R = 6371000; // Radius of Earth in meters
            var dLat = (lat2 - lat1) * Math.PI / 180.0;
            var dLon = (lon2 - lon1) * Math.PI / 180.0;
            var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                    Math.Cos(lat1 * Math.PI / 180.0) * Math.Cos(lat2 * Math.PI / 180.0) *
                    Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
            var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
            return R * c;
        }

        // ====================================================================
        // HEALTH CHECK / PING
        // ====================================================================
        [HttpGet("")]
        [HttpGet("ping")]
        [HttpGet("test")]
        [AllowAnonymous]
        public IActionResult Ping()
        {
            return Ok(new
            {
                status = "online",
                service = "TechnoArt Mobile REST API",
                timestamp = DateTime.UtcNow.ToString("o"),
                version = "1.0.0"
            });
        }

        // ====================================================================
        // 1. AUTHENTICATION ENDPOINTS
        // ====================================================================

        /// <summary>
        /// GET instruction endpoint to guide developers testing in Postman or browser.
        /// Route: GET /api/mobile/auth/login or GET /api/mobile/login
        /// </summary>
        [HttpGet("auth/login")]
        [HttpGet("login")]
        [AllowAnonymous]
        public IActionResult LoginGetInstruction()
        {
            return Ok(new
            {
                status = "endpoint_active",
                message = "The authentication endpoint requires an HTTP POST request with JSON credentials.",
                method = "POST",
                url = "/api/mobile/auth/login",
                headers = new { Content_Type = "application/json" },
                sampleBody = new { username = "your_username_or_userid", password = "your_password" }
            });
        }

        /// <summary>
        /// Authenticate user credentials and return JWT bearer token with user profile.
        /// Route: POST /api/mobile/auth/login or POST /api/mobile/login
        /// </summary>
        [HttpPost("auth/login")]
        [HttpPost("login")]
        [AllowAnonymous]
        public async Task<IActionResult> Login([FromBody] MobileLoginRequest request)
        {
            var userIdentifier = request?.Username ?? request?.UserId ?? request?.Email;
            if (request == null || string.IsNullOrWhiteSpace(userIdentifier) || string.IsNullOrWhiteSpace(request.Password))
            {
                return BadRequest(new { success = false, message = "Username / User ID and password are required." });
            }

            try
            {
                var cleanId = userIdentifier.Trim();
                var client = _clientFactory.CreateClient("SupportAPI");
                var authPayload = new { userId = cleanId, username = cleanId, password = request.Password };
                var response = await client.PostAsJsonAsync("api/auth/login", authPayload);

                if (!response.IsSuccessStatusCode)
                {
                    return Unauthorized(new { success = false, message = "Invalid credentials or unauthorized account." });
                }

                var result = await response.Content.ReadFromJsonAsync<JsonElement>();
                string? token = null;
                if (result.TryGetProperty("tokenres", out var tp1) && tp1.ValueKind == JsonValueKind.String) token = tp1.GetString();
                else if (result.TryGetProperty("token", out var tp2) && tp2.ValueKind == JsonValueKind.String) token = tp2.GetString();
                else if (result.TryGetProperty("accessToken", out var tp3) && tp3.ValueKind == JsonValueKind.String) token = tp3.GetString();
                else if (result.TryGetProperty("access_token", out var tp4) && tp4.ValueKind == JsonValueKind.String) token = tp4.GetString();

                if (string.IsNullOrEmpty(token))
                {
                    return Unauthorized(new { success = false, message = "Authentication failed: No access token issued." });
                }

                var (userId, username, role, tenantId) = GetUserContextFromToken(token);

                return Ok(new
                {
                    success = true,
                    message = "Login successful.",
                    token = token,
                    user = new
                    {
                        id = userId,
                        username = username,
                        role = role,
                        tenantId = tenantId
                    }
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = "Server error during authentication: " + ex.Message });
            }
        }

        /// <summary>
        /// Get profile information of the currently authenticated user.
        /// Route: GET /api/mobile/auth/profile
        /// </summary>
        [HttpGet("auth/profile")]
        public async Task<IActionResult> GetProfile()
        {
            var token = GetBearerToken();
            if (string.IsNullOrEmpty(token))
            {
                return Unauthorized(new { success = false, message = "Authorization token missing or invalid." });
            }

            var (userId, username, role, tenantId) = GetUserContextFromToken(token);
            if (string.IsNullOrEmpty(userId) && string.IsNullOrEmpty(username))
            {
                return Unauthorized(new { success = false, message = "Invalid token claims." });
            }

            try
            {
                var req = new APIDataAccParms
                {
                    ProcName = "sp_ticket_operations",
                    ProcID = "GET_EMPLOYEES",
                    parm01 = tenantId,
                    parm04 = username
                };

                var res = await _apiService.FetchDataAsync(req, token);
                return Ok(new
                {
                    success = true,
                    profile = new
                    {
                        userId = userId,
                        username = username,
                        role = role,
                        tenantId = tenantId,
                        details = res
                    }
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = "Error loading profile: " + ex.Message });
            }
        }

        // ====================================================================
        // 2. OFFICE HUBS & GEOFENCE
        // ====================================================================

        /// <summary>
        /// Get list of active office branches / hubs with coordinates and geofence radius.
        /// Route: GET /api/mobile/branches
        /// </summary>
        [HttpGet("branches")]
        public async Task<IActionResult> GetBranches()
        {
            var token = GetBearerToken();
            try
            {
                var req = new APIDataAccParms
                {
                    ProcName = "sp_ticket_operations",
                    ProcID = "GET_BRANCHES"
                };

                var res = await _apiService.FetchDataAsync(req, token);
                return Ok(new
                {
                    success = true,
                    branches = res
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = "Error loading branches: " + ex.Message });
            }
        }

        /// <summary>
        /// Verify whether user's current GPS coordinates fall within any active office branch radius.
        /// Route: POST /api/mobile/attendance/verify-geofence
        /// </summary>
        [HttpPost("attendance/verify-geofence")]
        public async Task<IActionResult> VerifyGeofence([FromBody] GeofenceCheckRequest request)
        {
            if (request == null || request.Latitude == 0 || request.Longitude == 0)
            {
                return BadRequest(new { success = false, message = "Valid latitude and longitude are required." });
            }

            var token = GetBearerToken();
            try
            {
                var req = new APIDataAccParms
                {
                    ProcName = "sp_ticket_operations",
                    ProcID = "GET_BRANCHES"
                };

                var res = await _apiService.FetchDataAsync(req, token);
                if (!res.HasValue)
                {
                    return Ok(new { success = true, isWithinOffice = false, message = "No active branches found." });
                }

                var target = res.Value;
                bool isInside = false;
                string matchedBranchName = "";
                string matchedBranchId = "";
                double minDistance = double.MaxValue;

                void CheckElement(JsonElement b)
                {
                    double bLat = 0, bLon = 0;
                    int bRad = 150;
                    if (b.TryGetProperty("latitude", out var latProp)) bLat = latProp.GetDouble();
                    if (b.TryGetProperty("longitude", out var lonProp)) bLon = lonProp.GetDouble();
                    if (b.TryGetProperty("radius", out var radProp)) bRad = radProp.GetInt32();
                    else if (b.TryGetProperty("radius_meters", out var rmProp)) bRad = rmProp.GetInt32();

                    var dist = CalculateDistanceMeters(request.Latitude, request.Longitude, bLat, bLon);
                    if (dist < minDistance) minDistance = dist;

                    if (dist <= bRad)
                    {
                        isInside = true;
                        matchedBranchName = b.TryGetProperty("name", out var n) ? n.GetString() ?? "" : "";
                        matchedBranchId = b.TryGetProperty("id", out var idProp) ? idProp.GetString() ?? "" : "";
                    }
                }

                if (target.ValueKind == JsonValueKind.Array)
                {
                    foreach (var el in target.EnumerateArray()) CheckElement(el);
                }
                else if (target.ValueKind == JsonValueKind.Object)
                {
                    CheckElement(target);
                }

                return Ok(new
                {
                    success = true,
                    isWithinOffice = isInside,
                    nearestDistanceMeters = Math.Round(minDistance, 1),
                    matchedBranchName = matchedBranchName,
                    matchedBranchId = matchedBranchId,
                    message = isInside 
                        ? $"Within permitted radius of {matchedBranchName}."
                        : $"Outside office radius (Nearest: {Math.Round(minDistance)}m away)."
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = "Geofence check error: " + ex.Message });
            }
        }

        // ====================================================================
        // 3. ATTENDANCE (Punch In, Punch Out, Today, History, Office Time)
        // ====================================================================

        /// <summary>
        /// Get shift timing, grace time, and late cutoff parameters.
        /// Route: GET /api/mobile/attendance/office-time
        /// </summary>
        [HttpGet("attendance/office-time")]
        public async Task<IActionResult> GetOfficeTime()
        {
            var token = GetBearerToken();
            try
            {
                var req = new APIDataAccParms
                {
                    ProcName = "sp_ticket_operations",
                    ProcID = "GET_OFFICE_TIME"
                };

                var res = await _apiService.FetchDataAsync(req, token);
                return Ok(new { success = true, officeTime = res });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = "Error loading office timing: " + ex.Message });
            }
        }

        /// <summary>
        /// Get today's attendance status for the authenticated user.
        /// Route: GET /api/mobile/attendance/today
        /// </summary>
        [HttpGet("attendance/today")]
        public async Task<IActionResult> GetTodayAttendance([FromQuery] string? date = null)
        {
            var token = GetBearerToken();
            if (string.IsNullOrEmpty(token))
            {
                return Unauthorized(new { success = false, message = "Authorization token missing." });
            }

            var (_, username, _, _) = GetUserContextFromToken(token);
            var targetDate = string.IsNullOrWhiteSpace(date) ? DateTime.Today.ToString("yyyy-MM-dd") : date.Trim();

            try
            {
                var req = new APIDataAccParms
                {
                    ProcName = "sp_ticket_operations",
                    ProcID = "GET_TODAY_ATTENDANCE",
                    parm01 = username,
                    parm02 = targetDate
                };

                var res = await _apiService.FetchDataAsync(req, token);
                return Ok(new
                {
                    success = true,
                    date = targetDate,
                    username = username,
                    attendance = res
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = "Error loading today's attendance: " + ex.Message });
            }
        }

        /// <summary>
        /// Clock in / Punch in attendance with GPS coordinates.
        /// Route: POST /api/mobile/attendance/punch-in
        /// </summary>
        [HttpPost("attendance/punch-in")]
        public async Task<IActionResult> PunchIn([FromBody] AttendancePunchRequest request)
        {
            var token = GetBearerToken();
            if (string.IsNullOrEmpty(token))
            {
                return Unauthorized(new { success = false, message = "Authorization token missing." });
            }

            var (userId, username, _, _) = GetUserContextFromToken(token);
            if (request == null)
            {
                return BadRequest(new { success = false, message = "Punch request payload is required." });
            }

            try
            {
                var req = new APIDataAccParms
                {
                    ProcName = "sp_ticket_operations",
                    ProcID = "CHECK_IN",
                    parm01 = !string.IsNullOrEmpty(username) ? username : userId,
                    parm02 = DateTime.UtcNow.ToString("o"),
                    parm03 = request.Latitude.ToString("F6", System.Globalization.CultureInfo.InvariantCulture),
                    parm04 = request.Longitude.ToString("F6", System.Globalization.CultureInfo.InvariantCulture),
                    parm05 = request.IsWfh ? "1" : "0",
                    parm06 = request.BranchId ?? "",
                    Desc01 = request.Remarks ?? ""
                };

                var res = await _apiService.FetchDataAsync(req, token);
                return Ok(new
                {
                    success = true,
                    message = "Clock-in recorded successfully! HR verification pending.",
                    time = DateTime.Now.ToString("hh:mm tt"),
                    date = DateTime.Today.ToString("yyyy-MM-dd"),
                    isWfh = request.IsWfh,
                    result = res
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = "Punch-in error: " + ex.Message });
            }
        }

        /// <summary>
        /// Clock out / Punch out attendance with GPS coordinates.
        /// Route: POST /api/mobile/attendance/punch-out
        /// </summary>
        [HttpPost("attendance/punch-out")]
        public async Task<IActionResult> PunchOut([FromBody] AttendancePunchRequest request)
        {
            var token = GetBearerToken();
            if (string.IsNullOrEmpty(token))
            {
                return Unauthorized(new { success = false, message = "Authorization token missing." });
            }

            var (userId, username, _, _) = GetUserContextFromToken(token);
            if (request == null)
            {
                return BadRequest(new { success = false, message = "Punch request payload is required." });
            }

            try
            {
                var req = new APIDataAccParms
                {
                    ProcName = "sp_ticket_operations",
                    ProcID = "CHECK_OUT",
                    parm01 = !string.IsNullOrEmpty(username) ? username : userId,
                    parm02 = DateTime.UtcNow.ToString("o"),
                    parm03 = request.Latitude.ToString("F6", System.Globalization.CultureInfo.InvariantCulture),
                    parm04 = request.Longitude.ToString("F6", System.Globalization.CultureInfo.InvariantCulture),
                    Desc01 = request.Remarks ?? ""
                };

                var res = await _apiService.FetchDataAsync(req, token);
                return Ok(new
                {
                    success = true,
                    message = "Clock-out recorded successfully! HR verification pending.",
                    time = DateTime.Now.ToString("hh:mm tt"),
                    date = DateTime.Today.ToString("yyyy-MM-dd"),
                    result = res
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = "Punch-out error: " + ex.Message });
            }
        }

        /// <summary>
        /// Get monthly or historical attendance logs for the employee.
        /// Route: GET /api/mobile/attendance/history
        /// </summary>
        [HttpGet("attendance/history")]
        public async Task<IActionResult> GetAttendanceHistory([FromQuery] string? month = null, [FromQuery] string? year = null)
        {
            var token = GetBearerToken();
            if (string.IsNullOrEmpty(token))
            {
                return Unauthorized(new { success = false, message = "Authorization token missing." });
            }

            var (userId, username, role, _) = GetUserContextFromToken(token);
            try
            {
                var req = new APIDataAccParms
                {
                    ProcName = "sp_ticket_operations",
                    ProcID = "GET_ATTENDANCE_LOGS",
                    parm01 = !string.IsNullOrEmpty(username) ? username : userId,
                    parm02 = month ?? DateTime.Now.Month.ToString(),
                    parm03 = year ?? DateTime.Now.Year.ToString(),
                    parm05 = role
                };

                var res = await _apiService.FetchDataAsync(req, token);
                return Ok(new
                {
                    success = true,
                    logs = res
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = "Error loading attendance history: " + ex.Message });
            }
        }

        // ====================================================================
        // 4. LEAVES MANAGEMENT
        // ====================================================================

        /// <summary>
        /// Get leave request history and status for the current user.
        /// Route: GET /api/mobile/leaves
        /// </summary>
        [HttpGet("leaves")]
        public async Task<IActionResult> GetLeaves()
        {
            var token = GetBearerToken();
            if (string.IsNullOrEmpty(token))
            {
                return Unauthorized(new { success = false, message = "Authorization token missing." });
            }

            var (userId, username, role, _) = GetUserContextFromToken(token);
            try
            {
                var req = new APIDataAccParms
                {
                    ProcName = "sp_ticket_operations",
                    ProcID = "GET_LEAVES",
                    parm04 = !string.IsNullOrEmpty(userId) ? userId : username,
                    parm05 = role
                };

                var res = await _apiService.FetchDataAsync(req, token);
                return Ok(new
                {
                    success = true,
                    leaves = res
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = "Error loading leaves: " + ex.Message });
            }
        }

        /// <summary>
        /// Submit a new leave application (Full day or Short Leave / Late Pass / Early Exit).
        /// Route: POST /api/mobile/leaves/apply
        /// </summary>
        [HttpPost("leaves/apply")]
        public async Task<IActionResult> ApplyLeave([FromBody] ApplyLeaveRequest request)
        {
            var token = GetBearerToken();
            if (string.IsNullOrEmpty(token))
            {
                return Unauthorized(new { success = false, message = "Authorization token missing." });
            }

            if (request == null)
            {
                return BadRequest(new { success = false, message = "Leave request payload is required." });
            }

            // Detect if this is a Short Leave (Late Arrival / Early Departure)
            bool isShortLeave = request.IsShortLeave 
                || !string.IsNullOrWhiteSpace(request.ShortLeaveType)
                || (!string.IsNullOrEmpty(request.LeaveType) && request.LeaveType.Contains("Short", StringComparison.OrdinalIgnoreCase));

            string fromDate = !string.IsNullOrWhiteSpace(request.FromDate) ? request.FromDate.Trim() : DateTime.Today.ToString("yyyy-MM-dd");
            string toDate = !string.IsNullOrWhiteSpace(request.ToDate) ? request.ToDate.Trim() : fromDate;
            string leaveType = !string.IsNullOrWhiteSpace(request.LeaveType) ? request.LeaveType.Trim() : "Casual";

            if (isShortLeave)
            {
                string shortMode = request.ShortLeaveType?.ToUpperInvariant() == "EARLY_DEPARTURE" 
                    ? "Early Departure" 
                    : "Late Arrival";
                leaveType = $"Short Leave ({shortMode})";
                toDate = fromDate; // Short leave is for a single date
            }

            var (userId, username, _, _) = GetUserContextFromToken(token);
            try
            {
                string reasonText = request.Reason?.Trim() ?? (isShortLeave ? "Short leave pass" : "Personal leave");
                if (!string.IsNullOrWhiteSpace(request.ExpectedTime))
                {
                    reasonText += $" [Expected Time: {request.ExpectedTime.Trim()}]";
                }

                var req = new APIDataAccParms
                {
                    ProcName = "sp_ticket_operations",
                    ProcID = "APPLY_LEAVE",
                    parm01 = !string.IsNullOrEmpty(userId) ? userId : username,
                    parm02 = leaveType,
                    parm03 = fromDate,
                    parm04 = toDate,
                    parm05 = request.ExpectedTime ?? "",
                    parm06 = reasonText
                };

                var res = await _apiService.FetchDataAsync(req, token);
                return Ok(new
                {
                    success = true,
                    message = isShortLeave
                        ? "Short leave application submitted successfully. Late/Early penalties will be waived once approved."
                        : "Leave application submitted successfully for review.",
                    isShortLeave = isShortLeave,
                    leaveType = leaveType,
                    fromDate = fromDate,
                    toDate = toDate,
                    expectedTime = request.ExpectedTime,
                    result = res
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = "Error applying for leave: " + ex.Message });
            }
        }

        /// <summary>
        /// Approve or reject leave application and send SMTP email notification to employee.
        /// Route: POST /api/mobile/leaves/update-status
        /// </summary>
        [HttpPost("leaves/update-status")]
        public async Task<IActionResult> UpdateLeaveStatus([FromBody] UpdateLeaveStatusRequest request)
        {
            var token = GetBearerToken();
            if (string.IsNullOrEmpty(token))
            {
                return Unauthorized(new { success = false, message = "Authorization token missing." });
            }

            if (request == null || string.IsNullOrWhiteSpace(request.LeaveId))
            {
                return BadRequest(new { success = false, message = "LeaveId is required." });
            }

            var (userId, username, role, _) = GetUserContextFromToken(token);
            try
            {
                string status = (request.Status?.Trim().ToUpperInvariant() == "APPROVED" || request.IsApprove == true) ? "APPROVED" : "REJECTED";
                string approverName = !string.IsNullOrEmpty(username) ? username : (!string.IsNullOrEmpty(role) ? role : "HR / Management");
                string remarks = !string.IsNullOrWhiteSpace(request.Remarks)
                    ? request.Remarks.Trim()
                    : $"{(status == "APPROVED" ? "Approved" : "Rejected")} via Mobile API by {approverName}";

                var req = new APIDataAccParms
                {
                    ProcName = "sp_ticket_operations",
                    ProcID = "UPDATE_LEAVE_STATUS",
                    parm01 = request.LeaveId.Trim(),
                    parm02 = status,
                    parm03 = remarks,
                    parm04 = userId,
                    parm05 = role
                };

                var res = await _apiService.FetchDataAsync(req, token);

                // Asynchronously dispatch SMTP email notification to employee
                if (_emailService != null)
                {
                    _ = Task.Run(async () =>
                    {
                        try
                        {
                            string empEmail = request.EmployeeEmail?.Trim() ?? "";
                            string empName = request.EmployeeName?.Trim() ?? "Employee";

                            // If email not provided in payload, look up user
                            if (string.IsNullOrEmpty(empEmail) || !empEmail.Contains("@"))
                            {
                                string targetLookup = !string.IsNullOrEmpty(request.EmployeeId) ? request.EmployeeId : request.EmployeeName ?? "";
                                if (!string.IsNullOrEmpty(targetLookup))
                                {
                                    var uReq = new APIDataAccParms
                                    {
                                        ProcName = "sp_ticket_operations",
                                        ProcID = "GET_USERS",
                                        parm04 = targetLookup
                                    };
                                    var uRes = await _apiService.FetchDataAsync(uReq, token);
                                    if (uRes.HasValue && uRes.Value.ValueKind == JsonValueKind.Array && uRes.Value.GetArrayLength() > 0)
                                    {
                                        var first = uRes.Value[0];
                                        if (first.TryGetProperty("email", out var emP) && !string.IsNullOrWhiteSpace(emP.GetString()))
                                        {
                                            empEmail = emP.GetString()!;
                                        }
                                        if (first.TryGetProperty("name", out var nmP) && !string.IsNullOrWhiteSpace(nmP.GetString()))
                                        {
                                            empName = nmP.GetString()!;
                                        }
                                    }
                                }
                            }

                            if (!string.IsNullOrEmpty(empEmail) && empEmail.Contains("@"))
                            {
                                await _emailService.SendLeaveStatusEmailAsync(
                                    empEmail,
                                    empName,
                                    request.LeaveType ?? "Leave",
                                    request.FromDate ?? DateTime.Today.ToString("yyyy-MM-dd"),
                                    request.ToDate ?? DateTime.Today.ToString("yyyy-MM-dd"),
                                    status,
                                    remarks
                                );
                            }
                        }
                        catch { }
                    });
                }

                return Ok(new
                {
                    success = true,
                    message = $"Leave request has been {status.ToLowerInvariant()} successfully.",
                    status = status,
                    remarks = remarks,
                    result = res
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = "Error updating leave status: " + ex.Message });
            }
        }

        // ====================================================================
        // 5. SUPPORT TICKETS
        // ====================================================================

        /// <summary>
        /// Get ticket queue list filtered by status and role.
        /// Route: GET /api/mobile/tickets
        /// </summary>
        [HttpGet("tickets")]
        public async Task<IActionResult> GetTickets([FromQuery] string? status = null, [FromQuery] string? priority = null)
        {
            var token = GetBearerToken();
            if (string.IsNullOrEmpty(token))
            {
                return Unauthorized(new { success = false, message = "Authorization token missing." });
            }

            var (userId, username, role, tenantId) = GetUserContextFromToken(token);
            try
            {
                var req = new APIDataAccParms
                {
                    ProcName = "sp_ticket_operations",
                    ProcID = "GET_TICKETS",
                    parm01 = tenantId,
                    parm02 = status ?? "",
                    parm03 = priority ?? "",
                    parm04 = !string.IsNullOrEmpty(userId) ? userId : username,
                    parm05 = role
                };

                var res = await _apiService.FetchDataAsync(req, token);
                return Ok(new
                {
                    success = true,
                    tickets = res
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = "Error loading tickets: " + ex.Message });
            }
        }

        /// <summary>
        /// Get ticket details, conversation history, and task checklist by Ticket Number.
        /// Route: GET /api/mobile/tickets/{ticketNumber}
        /// </summary>
        [HttpGet("tickets/{ticketNumber}")]
        public async Task<IActionResult> GetTicketDetails(string ticketNumber)
        {
            if (string.IsNullOrWhiteSpace(ticketNumber))
            {
                return BadRequest(new { success = false, message = "TicketNumber is required." });
            }

            var token = GetBearerToken();
            try
            {
                var req = new APIDataAccParms
                {
                    ProcName = "sp_ticket_operations",
                    ProcID = "GET_TICKET_DETAILS",
                    parm01 = ticketNumber.Trim()
                };

                var res = await _apiService.FetchDataAsync(req, token);
                return Ok(new
                {
                    success = true,
                    ticketNumber = ticketNumber,
                    details = res
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = "Error loading ticket details: " + ex.Message });
            }
        }

        /// <summary>
        /// Create / Raise a new support ticket.
        /// Route: POST /api/mobile/tickets/create
        /// </summary>
        [HttpPost("tickets/create")]
        public async Task<IActionResult> CreateTicket([FromBody] CreateTicketRequest request)
        {
            var token = GetBearerToken();
            if (string.IsNullOrEmpty(token))
            {
                return Unauthorized(new { success = false, message = "Authorization token missing." });
            }

            if (request == null || string.IsNullOrWhiteSpace(request.Title) || string.IsNullOrWhiteSpace(request.Description))
            {
                return BadRequest(new { success = false, message = "Title and Description are required." });
            }

            var (userId, username, role, tenantId) = GetUserContextFromToken(token);
            try
            {
                var req = new APIDataAccParms
                {
                    ProcName = "sp_ticket_operations",
                    ProcID = "CREATE_TICKET",
                    ComCod = !string.IsNullOrEmpty(request.TenantId) ? request.TenantId : tenantId,
                    parm01 = request.ProjectId ?? "",
                    parm02 = request.Title.Trim(),
                    parm03 = request.Priority ?? "MEDIUM",
                    parm04 = !string.IsNullOrEmpty(userId) ? userId : username,
                    parm05 = request.ModuleId ?? "",
                    parm06 = request.Description.Trim(),
                    parm07 = role
                };

                var res = await _apiService.FetchDataAsync(req, token);
                return Ok(new
                {
                    success = true,
                    message = "Ticket created successfully.",
                    result = res
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = "Error creating ticket: " + ex.Message });
            }
        }

        /// <summary>
        /// Add a reply/comment to an existing ticket.
        /// Route: POST /api/mobile/tickets/{ticketNumber}/comments
        /// </summary>
        [HttpPost("tickets/{ticketNumber}/comments")]
        public async Task<IActionResult> AddTicketComment(string ticketNumber, [FromBody] AddCommentRequest request)
        {
            var token = GetBearerToken();
            if (string.IsNullOrEmpty(token))
            {
                return Unauthorized(new { success = false, message = "Authorization token missing." });
            }

            if (string.IsNullOrWhiteSpace(ticketNumber) || request == null || string.IsNullOrWhiteSpace(request.Comment))
            {
                return BadRequest(new { success = false, message = "TicketNumber and Comment are required." });
            }

            var (userId, username, _, _) = GetUserContextFromToken(token);
            try
            {
                var req = new APIDataAccParms
                {
                    ProcName = "sp_ticket_operations",
                    ProcID = "ADD_COMMENT",
                    parm01 = ticketNumber.Trim(),
                    parm02 = request.Comment.Trim(),
                    parm06 = request.Comment.Trim(),
                    parm04 = !string.IsNullOrEmpty(userId) ? userId : username
                };

                var res = await _apiService.FetchDataAsync(req, token);
                return Ok(new
                {
                    success = true,
                    message = "Comment added successfully.",
                    result = res
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = "Error posting comment: " + ex.Message });
            }
        }

        /// <summary>
        /// Upload ticket attachment or camera photo from mobile app.
        /// Route: POST /api/mobile/tickets/upload
        /// </summary>
        [HttpPost("tickets/upload")]
        [RequestSizeLimit(25 * 1024 * 1024)]
        public async Task<IActionResult> UploadTicketAttachment([FromForm] IFormFile? file)
        {
            var token = GetBearerToken();
            if (string.IsNullOrEmpty(token))
            {
                return Unauthorized(new { success = false, message = "Authorization token missing." });
            }

            if (file == null || file.Length == 0)
            {
                return BadRequest(new { success = false, message = "No file received in multipart request." });
            }

            try
            {
                var webRoot = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot");
                var uploadsDir = Path.Combine(webRoot, "uploads", "tickets");
                if (!Directory.Exists(uploadsDir))
                {
                    Directory.CreateDirectory(uploadsDir);
                }

                var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
                var safeFileName = $"upload_{DateTime.UtcNow:yyyyMMdd_HHmmss}_{Guid.NewGuid():N}{ext}";
                var fullPath = Path.Combine(uploadsDir, safeFileName);

                using (var stream = new FileStream(fullPath, FileMode.Create))
                {
                    await file.CopyToAsync(stream);
                }

                var relativeUrl = $"/uploads/tickets/{safeFileName}";
                return Ok(new
                {
                    success = true,
                    message = "File uploaded successfully.",
                    originalName = file.FileName,
                    fileUrl = relativeUrl,
                    fileSize = file.Length
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = "File upload failed: " + ex.Message });
            }
        }

        // ====================================================================
        // 6. NOTICES & ANNOUNCEMENTS
        // ====================================================================

        /// <summary>
        /// Get active company notices and announcements.
        /// Route: GET /api/mobile/notices
        /// </summary>
        [HttpGet("notices")]
        public async Task<IActionResult> GetNotices()
        {
            var token = GetBearerToken();
            try
            {
                var req = new APIDataAccParms
                {
                    ProcName = "sp_ticket_operations",
                    ProcID = "GET_NOTICES"
                };

                var res = await _apiService.FetchDataAsync(req, token);
                return Ok(new
                {
                    success = true,
                    notices = res
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = "Error loading notices: " + ex.Message });
            }
        }

        // ====================================================================
        // 7. TASKS TRACKER
        // ====================================================================

        /// <summary>
        /// Get assigned tasks for the authenticated user.
        /// Route: GET /api/mobile/tasks
        /// </summary>
        [HttpGet("tasks")]
        public async Task<IActionResult> GetTasks()
        {
            var token = GetBearerToken();
            if (string.IsNullOrEmpty(token))
            {
                return Unauthorized(new { success = false, message = "Authorization token missing." });
            }

            var (userId, username, role, _) = GetUserContextFromToken(token);
            try
            {
                var req = new APIDataAccParms
                {
                    ProcName = "sp_ticket_operations",
                    ProcID = "GET_TASKS",
                    parm01 = !string.IsNullOrEmpty(userId) ? userId : username,
                    parm05 = role
                };

                var res = await _apiService.FetchDataAsync(req, token);
                return Ok(new
                {
                    success = true,
                    tasks = res
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = "Error loading tasks: " + ex.Message });
            }
        }

        /// <summary>
        /// Update task status (TODO, IN_PROGRESS, COMPLETED).
        /// Route: POST /api/mobile/tasks/{taskId}/status
        /// </summary>
        [HttpPost("tasks/{taskId}/status")]
        public async Task<IActionResult> UpdateTaskStatus(string taskId, [FromBody] UpdateTaskStatusRequest request)
        {
            var token = GetBearerToken();
            if (string.IsNullOrEmpty(token))
            {
                return Unauthorized(new { success = false, message = "Authorization token missing." });
            }

            if (string.IsNullOrWhiteSpace(taskId) || request == null || string.IsNullOrWhiteSpace(request.Status))
            {
                return BadRequest(new { success = false, message = "TaskId and Status are required." });
            }

            try
            {
                var req = new APIDataAccParms
                {
                    ProcName = "sp_ticket_operations",
                    ProcID = "UPDATE_TASK_STATUS",
                    parm01 = taskId.Trim(),
                    parm02 = request.Status.Trim().ToUpperInvariant()
                };

                var res = await _apiService.FetchDataAsync(req, token);
                return Ok(new
                {
                    success = true,
                    message = "Task status updated successfully.",
                    result = res
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = "Error updating task: " + ex.Message });
            }
        }

        // ====================================================================
        // 8. NOTIFICATIONS & FCM PUSH TOKEN
        // ====================================================================

        /// <summary>
        /// Get unread notifications for the user.
        /// Route: GET /api/mobile/notifications
        /// </summary>
        [HttpGet("notifications")]
        public async Task<IActionResult> GetNotifications()
        {
            var token = GetBearerToken();
            if (string.IsNullOrEmpty(token))
            {
                return Unauthorized(new { success = false, message = "Authorization token missing." });
            }

            var (userId, username, _, _) = GetUserContextFromToken(token);
            try
            {
                var req = new APIDataAccParms
                {
                    ProcName = "sp_ticket_operations",
                    ProcID = "GET_NOTIFICATIONS",
                    parm04 = !string.IsNullOrEmpty(userId) ? userId : username
                };

                var res = await _apiService.FetchDataAsync(req, token);
                return Ok(new
                {
                    success = true,
                    notifications = res
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = "Error loading notifications: " + ex.Message });
            }
        }

        /// <summary>
        /// Register FCM device token for mobile push notifications.
        /// Route: POST /api/mobile/notifications/register-token
        /// </summary>
        [HttpPost("notifications/register-token")]
        public async Task<IActionResult> RegisterFcmToken([FromBody] RegisterFcmTokenRequest request)
        {
            var token = GetBearerToken();
            if (string.IsNullOrEmpty(token))
            {
                return Unauthorized(new { success = false, message = "Authorization token missing." });
            }

            if (request == null || string.IsNullOrWhiteSpace(request.FcmToken))
            {
                return BadRequest(new { success = false, message = "FcmToken is required." });
            }

            var (userId, username, _, _) = GetUserContextFromToken(token);
            try
            {
                var req = new APIDataAccParms
                {
                    ProcName = "sp_ticket_operations",
                    ProcID = "REGISTER_FCM_TOKEN",
                    parm01 = request.FcmToken.Trim(),
                    parm08 = !string.IsNullOrEmpty(userId) ? userId : username
                };

                var res = await _apiService.FetchDataAsync(req, token);
                return Ok(new
                {
                    success = true,
                    message = "FCM push token registered successfully.",
                    result = res
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = "Error registering FCM token: " + ex.Message });
            }
        }
    }

    // ========================================================================
    // REQUEST DTO MODELS
    // ========================================================================

    public class MobileLoginRequest
    {
        public string? Username { get; set; }
        public string? UserId { get; set; }
        public string? Email { get; set; }
        public string Password { get; set; } = "";
    }

    public class GeofenceCheckRequest
    {
        public double Latitude { get; set; }
        public double Longitude { get; set; }
    }

    public class AttendancePunchRequest
    {
        public double Latitude { get; set; }
        public double Longitude { get; set; }
        public string? BranchId { get; set; }
        public bool IsWfh { get; set; } = false;
        public string? Remarks { get; set; }
    }

    public class ApplyLeaveRequest
    {
        public string LeaveType { get; set; } = "Casual";
        public string FromDate { get; set; } = "";
        public string ToDate { get; set; } = "";
        public string? Reason { get; set; }
        public bool IsShortLeave { get; set; } = false;
        public string? ShortLeaveType { get; set; } // "LATE_ARRIVAL" or "EARLY_DEPARTURE"
        public string? ExpectedTime { get; set; } // e.g. "12:00 PM" or "04:30 PM"
    }

    public class UpdateLeaveStatusRequest
    {
        public string LeaveId { get; set; } = "";
        public string? Status { get; set; } // "APPROVED" or "REJECTED"
        public bool? IsApprove { get; set; }
        public string? Remarks { get; set; }
        public string? EmployeeId { get; set; }
        public string? EmployeeName { get; set; }
        public string? EmployeeEmail { get; set; }
        public string? LeaveType { get; set; }
        public string? FromDate { get; set; }
        public string? ToDate { get; set; }
    }

    public class CreateTicketRequest
    {
        public string Title { get; set; } = "";
        public string Description { get; set; } = "";
        public string? Priority { get; set; } = "MEDIUM";
        public string? ProjectId { get; set; }
        public string? ModuleId { get; set; }
        public string? TenantId { get; set; }
    }

    public class AddCommentRequest
    {
        public string Comment { get; set; } = "";
    }

    public class UpdateTaskStatusRequest
    {
        public string Status { get; set; } = "COMPLETED";
    }

    public class RegisterFcmTokenRequest
    {
        public string FcmToken { get; set; } = "";
    }
}
