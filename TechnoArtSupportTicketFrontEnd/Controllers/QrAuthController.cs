using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Antiforgery;
using TechnoArtSupportTicketFrontEnd.Services;
using System.Text.Json;

namespace TechnoArtSupportTicketFrontEnd.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [IgnoreAntiforgeryToken]
    public class QrAuthController : ControllerBase
    {
        private readonly IQrAuthService _qrAuthService;

        public QrAuthController(IQrAuthService qrAuthService)
        {
            _qrAuthService = qrAuthService;
        }

        /// <summary>
        /// Generate a new QR auth session for Web login.
        /// Route: GET /api/qr/generate or GET /api/qrauth/generate
        /// </summary>
        [HttpGet("/api/qr/generate")]
        [HttpGet("generate")]
        [AllowAnonymous]
        public IActionResult GenerateQrSession()
        {
            var session = _qrAuthService.CreateSession();
            return Ok(new
            {
                success = true,
                sessionId = session.SessionId,
                qrData = session.SessionId,
                expiresInSeconds = 300
            });
        }

        /// <summary>
        /// Poll the status of a QR login session.
        /// Route: GET /api/qr/poll/{sessionId} or GET /api/qrauth/poll/{sessionId}
        /// </summary>
        [HttpGet("/api/qr/poll/{sessionId}")]
        [HttpGet("poll/{sessionId}")]
        [AllowAnonymous]
        public IActionResult PollSession(string sessionId)
        {
            var session = _qrAuthService.CheckSession(sessionId);
            if (session == null || session.Status == "EXPIRED_OR_INVALID")
            {
                return Ok(new
                {
                    status = "EXPIRED_OR_INVALID",
                    message = "Session expired or invalid. Please generate a new QR."
                });
            }

            return Ok(new
            {
                status = session.Status,
                token = session.Token,
                user = session.User
            });
        }

        /// <summary>
        /// Approve a QR session from Mobile App or external authorized device.
        /// Route: POST /api/qr/approve or POST /api/mobile/qr/approve
        /// </summary>
        [HttpPost("/api/qr/approve")]
        [HttpPost("/api/mobile/qr/approve")]
        [HttpPost("approve")]
        [AllowAnonymous]
        public IActionResult ApproveSession([FromBody] QrApproveRequest request)
        {
            if (request == null || string.IsNullOrWhiteSpace(request.SessionId))
            {
                return BadRequest(new { success = false, message = "Session ID is required." });
            }

            // Extract Bearer token from Header or Request body
            string? token = request.Token;
            if (string.IsNullOrWhiteSpace(token))
            {
                var authHeader = Request.Headers["Authorization"].ToString();
                if (!string.IsNullOrEmpty(authHeader) && authHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
                {
                    token = authHeader.Substring("Bearer ".Length).Trim();
                }
            }

            if (string.IsNullOrWhiteSpace(token))
            {
                return Unauthorized(new { success = false, message = "Authentication token is required to authorize QR sign-in." });
            }

            var ok = _qrAuthService.ApproveSession(request.SessionId.Trim(), token, request.User);
            if (!ok)
            {
                return BadRequest(new { success = false, message = "Session expired, invalid, or already processed." });
            }

            return Ok(new
            {
                success = true,
                message = "Web session approved successfully! Web browser is now logging in."
            });
        }
    }

    public class QrApproveRequest
    {
        public string SessionId { get; set; } = "";
        public string? Token { get; set; }
        public object? User { get; set; }
    }
}
