using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.DataProtection;
using PdfSharp.Fonts;
using RIS_HRO.Data;
using RIS_HRO.Repositories;
using RIS_HRO.Services;

var builder = WebApplication.CreateBuilder(args);

if (OperatingSystem.IsWindows())
{
    // PDFsharp Core 6.2+: enables common Windows fonts such as Arial.
    // The deployment guide therefore recommends Azure App Service on Windows.
    GlobalFontSettings.UseWindowsFontsUnderWindows = true;
}

builder.Services
    .AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.LoginPath = "/Account/Login";
        options.AccessDeniedPath = "/Account/AccessDenied";
        options.Cookie.Name = "RIS_HRO.Auth";
        options.ExpireTimeSpan = TimeSpan.FromHours(8);
        options.SlidingExpiration = true;
        options.Cookie.HttpOnly = true;
        options.Cookie.SameSite = SameSiteMode.Lax;
        options.Cookie.SecurePolicy = CookieSecurePolicy.SameAsRequest;
    });

builder.Services.AddAuthorization();
builder.Services.AddRazorPages(options =>
{
    //options.Conventions.AuthorizeFolder("/");
    //options.Conventions.AllowAnonymousToPage("/Account/Login");

    // Edgar -> Cambio para mostrar olvido su contraseña

    // Todo el sistema requiere autenticación
    options.Conventions.AuthorizeFolder("/");

    // Estas páginas deben funcionar SIN haber iniciado sesión
    options.Conventions.AllowAnonymousToPage("/Account/Login");
    options.Conventions.AllowAnonymousToPage("/Account/ForgotPassword");
});

builder.Services.AddHttpClient();

builder.Services.AddSingleton<SqlConnectionFactory>();
builder.Services.AddScoped<PasswordService>();
builder.Services.AddScoped<Hl7ParserService>();
builder.Services.AddScoped<PdfService>();

builder.Services.AddScoped<AuthRepository>();
builder.Services.AddScoped<DashboardRepository>();
builder.Services.AddScoped<PatientRepository>();
builder.Services.AddScoped<CatalogRepository>();
builder.Services.AddScoped<UserRepository>();
builder.Services.AddScoped<CapacityRepository>();
builder.Services.AddScoped<AppointmentRepository>();
builder.Services.AddScoped<ReportRepository>();

builder.Services.AddScoped<IHospitalPatientService, HospitalPatientService>();
builder.Services.AddScoped<PatientLookupService>();
//Edgar -> agregado para recuperacion de contraseñas

builder.Services.AddDataProtection()
    .SetApplicationName("RIS_HRO");

builder.Services.AddScoped<PasswordRecoveryRepository>();
builder.Services.AddScoped<EmailSettingsRepository>();

builder.Services.AddScoped<EmailSecretProtector>();
builder.Services.AddScoped<TemporaryPasswordGenerator>();
builder.Services.AddScoped<EmailSenderService>();

// 
var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthentication();
// //Edgar -> agregado para recuperacion de contraseñas
app.Use(async (context, next) =>
{
    var mustChange =
        context.User.Identity?.IsAuthenticated == true &&
        context.User.HasClaim(
            "RIS_HRO.MustChangePassword", "true");

    var path = context.Request.Path;

    var allowed =
        path.StartsWithSegments("/Account/ChangePassword") ||
        path.StartsWithSegments("/Account/Logout");

    if (mustChange && !allowed)
    {
        context.Response.Redirect(
            "/Account/ChangePassword");
        return;
    }

    await next();
});

//

app.UseAuthorization();
app.MapRazorPages();

app.Run();
