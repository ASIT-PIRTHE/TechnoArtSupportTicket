using System;
using System.Net;
using System.Net.Mail;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace TechnoArtSupportTicketFrontEnd.Services
{
    public interface IEmailService
    {
        Task<bool> SendEmailAsync(string toEmail, string subject, string htmlBody);
        Task<bool> SendLeaveStatusEmailAsync(string toEmail, string employeeName, string leaveType, string fromDate, string toDate, string status, string remarks, string approverTitle = "Supervisor / HR");
    }

    public class EmailService : IEmailService
    {
        private readonly IConfiguration _config;
        private readonly ILogger<EmailService> _logger;

        public EmailService(IConfiguration config, ILogger<EmailService> logger)
        {
            _config = config;
            _logger = logger;
        }

        public async Task<bool> SendEmailAsync(string toEmail, string subject, string htmlBody)
        {
            if (string.IsNullOrWhiteSpace(toEmail))
            {
                _logger.LogWarning("Email recipient address is blank. Skipping email send.");
                return false;
            }

            try
            {
                var host = _config["Smtp:Host"] ?? "smtp.gmail.com";
                var portStr = _config["Smtp:Port"] ?? "587";
                var port = int.TryParse(portStr, out var p) ? p : 587;
                var enableSsl = bool.TryParse(_config["Smtp:EnableSsl"], out var ssl) ? ssl : true;
                var userName = _config["Smtp:UserName"];
                var password = _config["Smtp:Password"];
                var fromEmail = _config["Smtp:FromEmail"] ?? userName ?? "support@technoartsoft.com";
                var fromName = _config["Smtp:FromName"] ?? "TechnoArt Support & HR";

                if (string.IsNullOrWhiteSpace(userName) || string.IsNullOrWhiteSpace(password))
                {
                    _logger.LogInformation("SMTP credentials not configured in appsettings.json. Email send simulated for: {Recipient}", toEmail);
                    return false;
                }

                using var message = new MailMessage
                {
                    From = new MailAddress(fromEmail, fromName),
                    Subject = subject,
                    Body = htmlBody,
                    IsBodyHtml = true
                };
                message.To.Add(toEmail.Trim());

                using var client = new SmtpClient(host, port)
                {
                    EnableSsl = enableSsl,
                    UseDefaultCredentials = false,
                    Credentials = new NetworkCredential(userName, password),
                    Timeout = 10000
                };

                await client.SendMailAsync(message);
                _logger.LogInformation("Email successfully dispatched to {Recipient} | Subject: {Subject}", toEmail, subject);
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to send email to {Recipient}: {Message}", toEmail, ex.Message);
                return false;
            }
        }

        public async Task<bool> SendLeaveStatusEmailAsync(
            string toEmail, 
            string employeeName, 
            string leaveType, 
            string fromDate, 
            string toDate, 
            string status, 
            string remarks, 
            string approverTitle = "Supervisor / HR")
        {
            bool isApproved = string.Equals(status, "APPROVED", StringComparison.OrdinalIgnoreCase);
            var statusColor = isApproved ? "#198754" : "#dc3545";
            var statusBadge = isApproved ? "APPROVED" : "REJECTED";
            var subject = $"Leave Application {statusBadge}: {leaveType} ({fromDate} - {toDate})";

            var html = $@"
<!DOCTYPE html>
<html>
<head>
    <meta charset='utf-8'>
    <style>
        body {{ font-family: 'Segoe UI', Arial, sans-serif; background-color: #f6f8fb; margin: 0; padding: 20px; color: #212529; }}
        .card {{ max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.05); overflow: hidden; border: 1px solid #e9ecef; }}
        .header {{ background: linear-gradient(135deg, #2b3990 0%, #1e2865 100%); color: #ffffff; padding: 25px; text-align: center; }}
        .body {{ padding: 30px; }}
        .badge {{ display: inline-block; padding: 6px 14px; font-weight: bold; border-radius: 50px; font-size: 14px; background-color: {statusColor}; color: #ffffff; margin-bottom: 20px; }}
        .info-table {{ width: 100%; border-collapse: collapse; margin-top: 15px; margin-bottom: 20px; }}
        .info-table td {{ padding: 10px 12px; border-bottom: 1px solid #f1f3f5; font-size: 14px; }}
        .info-table td.label {{ color: #6c757d; font-weight: 600; width: 35%; }}
        .info-table td.val {{ font-weight: 600; color: #212529; }}
        .remarks-box {{ background-color: #f8f9fa; border-left: 4px solid {statusColor}; padding: 12px 16px; border-radius: 4px; font-size: 13px; color: #495057; margin-top: 10px; }}
        .footer {{ background-color: #f8f9fa; padding: 15px; text-align: center; font-size: 12px; color: #868e96; border-top: 1px solid #e9ecef; }}
    </style>
</head>
<body>
    <div class='card'>
        <div class='header'>
            <h2 style='margin:0; font-size: 22px; font-weight: 700;'>TechnoArt HR & Attendance Portal</h2>
            <p style='margin: 5px 0 0 0; opacity: 0.8; font-size: 13px;'>Leave Application Status Notification</p>
        </div>
        <div class='body'>
            <p style='font-size: 16px; margin-top: 0;'>Dear <strong>{employeeName}</strong>,</p>
            <p style='font-size: 14px; color: #495057;'>Your leave request has been reviewed by your <strong>{approverTitle}</strong>. The details are as follows:</p>
            
            <div style='text-align: center; margin: 15px 0;'>
                <span class='badge'>{statusBadge}</span>
            </div>

            <table class='info-table'>
                <tr>
                    <td class='label'>Leave Type</td>
                    <td class='val'>{leaveType}</td>
                </tr>
                <tr>
                    <td class='label'>Duration</td>
                    <td class='val'>{fromDate} to {toDate}</td>
                </tr>
                <tr>
                    <td class='label'>Reviewed By</td>
                    <td class='val'>{approverTitle}</td>
                </tr>
                <tr>
                    <td class='label'>Date Reviewed</td>
                    <td class='val'>{DateTime.Now.ToString("dd MMM yyyy, hh:mm tt")}</td>
                </tr>
            </table>

            {(string.IsNullOrWhiteSpace(remarks) ? "" : $"<div class='remarks-box'><strong>Review Remarks:</strong> {remarks}</div>")}

            <p style='font-size: 13px; color: #6c757d; margin-top: 25px;'>If you have any questions or require further adjustments, please contact the HR department or your supervisor.</p>
        </div>
        <div class='footer'>
            &copy; {DateTime.Now.Year} TechnoArt Limited. Automated HR System notification.
        </div>
    </div>
</body>
</html>";

            return await SendEmailAsync(toEmail, subject, html);
        }
    }
}
