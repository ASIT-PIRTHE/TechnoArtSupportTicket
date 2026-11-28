using TechnoArtSupportTicketFrontEnd.Components;
using Microsoft.AspNetCore.Components.Authorization;
using Microsoft.AspNetCore.Components.Server.ProtectedBrowserStorage;
using TechnoArtSupportTicketFrontEnd.Auth;
using MudBlazor.Services;
using Microsoft.AspNetCore.DataProtection;

var projectDir = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", ".."));
if (!Directory.Exists(Path.Combine(projectDir, "wwwroot")))
{
    projectDir = AppContext.BaseDirectory;
}
var builder = WebApplication.CreateBuilder(new WebApplicationOptions
{
    Args = args,
    ContentRootPath = projectDir,
    WebRootPath = Path.Combine(projectDir, "wwwroot")
});

// Add services to the container.
builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents(options => options.DetailedErrors = true);

builder.Services.AddControllers()
    .AddApplicationPart(typeof(TechnoArtSupportTicketFrontEnd.Controllers.MobileApiController).Assembly);

builder.Services.AddCors(options =>
{
    options.AddPolicy("MobileCorsPolicy", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

builder.Services.AddMudServices();

// QR Auth & SMTP Email Services
builder.Services.AddSingleton<TechnoArtSupportTicketFrontEnd.Services.IQrAuthService, TechnoArtSupportTicketFrontEnd.Services.QrAuthService>();
builder.Services.AddScoped<TechnoArtSupportTicketFrontEnd.Services.IEmailService, TechnoArtSupportTicketFrontEnd.Services.EmailService>();

// FIX FOR BLAZOR LOGOUT ON REFRESH & APP RESTART: Persist Encryption Keys
builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo(Path.Combine(builder.Environment.ContentRootPath, "App_Data", "Keys")))
    .SetApplicationName("TicketSupportApp");

// Setup Authentication and Global API Services from appsettings.json
var apiUrl = builder.Configuration.GetValue<string>("ApiBaseUrl") ?? "http://103.228.38.52:100";

// Keep legacy string named client for fallback backwards compatibility if used anywhere
builder.Services.AddHttpClient("SupportAPI", client => { client.BaseAddress = new Uri(apiUrl); });
builder.Services.AddScoped<TechnoArtSupportTicketFrontEnd.Services.ApiService>(sp => 
{
    var factory = sp.GetRequiredService<IHttpClientFactory>();
    var sessionStorage = sp.GetRequiredService<Microsoft.AspNetCore.Components.Server.ProtectedBrowserStorage.ProtectedSessionStorage>();
    var localStorage = sp.GetService<Microsoft.AspNetCore.Components.Server.ProtectedBrowserStorage.ProtectedLocalStorage>();
    return new TechnoArtSupportTicketFrontEnd.Services.ApiService(factory.CreateClient("SupportAPI"), sessionStorage, localStorage);
});

builder.Services.AddAuthentication(Microsoft.AspNetCore.Authentication.Cookies.CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options => {
        options.LoginPath = "/login";
    });
builder.Services.AddAuthorization();
builder.Services.AddCascadingAuthenticationState();
builder.Services.AddScoped<ProtectedLocalStorage>();
builder.Services.AddScoped<ProtectedSessionStorage>();
builder.Services.AddScoped<AuthenticationStateProvider, CustomAuthStateProvider>();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

app.UseCors("MobileCorsPolicy");
app.UseStaticFiles();
app.UseAntiforgery();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode()
    .AllowAnonymous();

app.Run();
