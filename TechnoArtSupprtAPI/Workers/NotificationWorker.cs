using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Npgsql;
using System.Text.Json;

namespace TechnoArtSupprtAPI.Workers
{
    public class NotificationWorker : BackgroundService
    {
        private readonly ILogger<NotificationWorker> _logger;
        private readonly string _connectionString;

        public NotificationWorker(ILogger<NotificationWorker> logger, IConfiguration configuration)
        {
            _logger = logger;
            _connectionString = configuration.GetConnectionString("PostgresConnStr") ?? ""; // Note: Map dynamically in prod
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("SupportHub Notification Outbox Worker running.");

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    using var conn = new NpgsqlConnection(_connectionString);
                    await conn.OpenAsync(stoppingToken);

                    // Fetch PENDING outbox messages (Transactionally lock via FOR UPDATE SKIP LOCKED)
                    var query = @"
                        UPDATE notification.outbox
                        SET status = 'PROCESSING', processing_started_at = NOW()
                        WHERE id = (
                            SELECT id FROM notification.outbox
                            WHERE status = 'PENDING'
                            ORDER BY created_at ASC
                            FOR UPDATE SKIP LOCKED
                            LIMIT 1
                        )
                        RETURNING id, event_type, payload;";

                    using var cmd = new NpgsqlCommand(query, conn);
                    using var reader = await cmd.ExecuteReaderAsync(stoppingToken);

                    if (await reader.ReadAsync(stoppingToken))
                    {
                        var id = reader.GetInt64(0);
                        var eventType = reader.GetString(1);
                        var payload = reader.GetString(2);

                        _logger.LogInformation($"Processing Notification Event: {eventType} | Payload: {payload}");

                        // SIMULATE SENDING NOTIFICATION (Email, FCM, SignalR)
                        await Task.Delay(500, stoppingToken);

                        // Mark as SUCCESS
                        var completeQuery = "UPDATE notification.outbox SET status = 'DELIVERED', processed_at = NOW() WHERE id = @id";
                        using var completeCmd = new NpgsqlConnection(_connectionString);
                        await completeCmd.OpenAsync(stoppingToken);
                        using var finalCmd = new NpgsqlCommand(completeQuery, completeCmd);
                        finalCmd.Parameters.AddWithValue("id", id);
                        await finalCmd.ExecuteNonQueryAsync(stoppingToken);
                    }
                    else
                    {
                        // No items, wait 3 seconds before next poll
                        await Task.Delay(3000, stoppingToken);
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error processing Notification Outbox");
                    await Task.Delay(5000, stoppingToken); // Backoff
                }
            }
        }
    }
}
