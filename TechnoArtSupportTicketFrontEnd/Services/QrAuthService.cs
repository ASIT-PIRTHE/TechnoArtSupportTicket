using System;
using System.Collections.Concurrent;

namespace TechnoArtSupportTicketFrontEnd.Services
{
    public class QrSessionState
    {
        public string SessionId { get; set; } = "";
        public string Status { get; set; } = "PENDING"; // PENDING, APPROVED, EXPIRED
        public string? Token { get; set; }
        public object? User { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime ExpiresAt { get; set; } = DateTime.UtcNow.AddMinutes(5);
    }

    public interface IQrAuthService
    {
        QrSessionState CreateSession();
        QrSessionState? CheckSession(string sessionId);
        bool ApproveSession(string sessionId, string token, object? user = null);
        void CleanupExpiredSessions();
    }

    public class QrAuthService : IQrAuthService
    {
        private readonly ConcurrentDictionary<string, QrSessionState> _sessions = new();

        public QrSessionState CreateSession()
        {
            CleanupExpiredSessions();

            var yymm = DateTime.UtcNow.ToString("yyMM");
            var randPart = Guid.NewGuid().ToString("N").Substring(0, 6).ToUpperInvariant();
            var sessionId = $"QR{yymm}{randPart}";

            var session = new QrSessionState
            {
                SessionId = sessionId,
                Status = "PENDING",
                CreatedAt = DateTime.UtcNow,
                ExpiresAt = DateTime.UtcNow.AddMinutes(5)
            };

            _sessions[sessionId] = session;
            return session;
        }

        public QrSessionState? CheckSession(string sessionId)
        {
            if (string.IsNullOrWhiteSpace(sessionId)) return null;

            if (_sessions.TryGetValue(sessionId.Trim(), out var session))
            {
                if (DateTime.UtcNow > session.ExpiresAt)
                {
                    session.Status = "EXPIRED_OR_INVALID";
                }
                return session;
            }

            return new QrSessionState
            {
                SessionId = sessionId,
                Status = "EXPIRED_OR_INVALID"
            };
        }

        public bool ApproveSession(string sessionId, string token, object? user = null)
        {
            if (string.IsNullOrWhiteSpace(sessionId) || string.IsNullOrWhiteSpace(token)) return false;

            if (_sessions.TryGetValue(sessionId.Trim(), out var session))
            {
                if (DateTime.UtcNow > session.ExpiresAt)
                {
                    session.Status = "EXPIRED_OR_INVALID";
                    return false;
                }

                session.Status = "APPROVED";
                session.Token = token;
                session.User = user;
                return true;
            }

            return false;
        }

        public void CleanupExpiredSessions()
        {
            var now = DateTime.UtcNow;
            foreach (var kvp in _sessions)
            {
                if (now > kvp.Value.ExpiresAt.AddMinutes(5))
                {
                    _sessions.TryRemove(kvp.Key, out _);
                }
            }
        }
    }
}
