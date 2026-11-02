using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using System.Text.Json;
using Npgsql;

namespace TechnoArtSupprtAPI
{
    public class NotificationService
    {
        private static bool isInitialized = false;

        public static void Initialize(IWebHostEnvironment env)
        {
            if (!isInitialized)
            {
                try
                {
                    string path = Path.Combine(env.ContentRootPath, "service-account.json");
                    if (File.Exists(path))
                    {
                        if (FirebaseApp.DefaultInstance == null)
                        {
                            FirebaseApp.Create(new AppOptions()
                            {
                                Credential = GoogleCredential.FromFile(path),
                            });
                        }
                        isInitialized = true;
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine("Firebase Init Error: " + ex.Message);
                }
            }
        }

        public static async Task FireTaskAssignmentPushAsync(string assignedToUserId, string taskId)
        {
            try
            {
                // Fetch FCM Token from DB
                string projectPath = AppDomain.CurrentDomain.BaseDirectory.Split(new string[] { @"bin\" }, StringSplitOptions.None)[0];
                IConfigurationRoot cfg = new ConfigurationBuilder().SetBasePath(projectPath).AddJsonFile("appsettings.json").Build();
                string connStr = cfg.GetConnectionString("PostgresConnStr") ?? "";

                string fcmToken = "";
                string title = "New Task Assigned";
                string body = $"You have been assigned to new task {taskId}. Please check your workspace.";

                using var conn = new NpgsqlConnection(connStr);
                await conn.OpenAsync();
                using var cmd = new NpgsqlCommand("SELECT fcm_token FROM support.user_fcm_tokens WHERE user_id = @u::UUID", conn);
                cmd.Parameters.AddWithValue("u", assignedToUserId);
                using var reader = await cmd.ExecuteReaderAsync();
                if (await reader.ReadAsync())
                {
                    fcmToken = reader.GetString(0);
                }

                if (!string.IsNullOrEmpty(fcmToken))
                {
                    var message = new Message()
                    {
                        Notification = new Notification()
                        {
                            Title = title,
                            Body = body
                        },
                        Data = new Dictionary<string, string>()
                        {
                            { "task_id", taskId }
                        },
                        Token = fcmToken,
                    };

                    string response = await FirebaseMessaging.DefaultInstance.SendAsync(message);
                    Console.WriteLine($"Successfully sent FCM push to {assignedToUserId}: " + response);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine("Push Notification Error: " + ex.Message);
            }
        }
    }
}
