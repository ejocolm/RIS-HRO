using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.DataProtection;
using PdfSharp.Fonts;
using RIS_HRO.Data;
using RIS_HRO.Repositories;
using RIS_HRO.Services;

var builder = WebApplication.CreateBuilder(args);

if (OperatingSystem.IsWindows())
{
    GlobalFontSettings.UseWindowsFontsUnderWindows = true;
}
else
{
    // PDFsharp Core 6.2 no resuelve fuentes automáticamente en Linux.
    // Docker instala Liberation Sans y este resolver la usa como sustituto de Arial.
    GlobalFontSettings.FontResolver = new LinuxFontResolver();
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
    options.Conventions.AuthorizeFolder("/");
    options.Conventions.AllowAnonymousToPage("/Account/Login");
    options.Conventions.AllowAnonymousToPage("/Account/ForgotPassword");
});

builder.Services.AddHttpClient();

builder.Services.AddSingleton<SqlConnectionFactory>();
builder.Services.AddScoped<PasswordService>();
builder.Services.AddScoped<Hl7ParserService>();
builder.Services.AddScoped<PdfService>();

// =============================================================
// RECUPERACIÓN DE CONTRASEÑA Y CONFIGURACIÓN DE CORREO
// =============================================================
var dataProtection = builder.Services.AddDataProtection()
    .SetApplicationName("RIS_HRO");

// En Docker se configura DataProtection__KeysPath para conservar las claves
// aunque el contenedor sea recreado. En desarrollo Windows se mantiene el
// comportamiento predeterminado si esta variable no está configurada.
var dataProtectionKeysPath = builder.Configuration["DataProtection:KeysPath"];
if (!string.IsNullOrWhiteSpace(dataProtectionKeysPath))
{
    Directory.CreateDirectory(dataProtectionKeysPath);
    dataProtection.PersistKeysToFileSystem(new DirectoryInfo(dataProtectionKeysPath));
}

builder.Services.AddScoped<PasswordRecoveryRepository>();
builder.Services.AddScoped<EmailSettingsRepository>();

builder.Services.AddScoped<EmailSecretProtector>();
builder.Services.AddScoped<TemporaryPasswordGenerator>();
builder.Services.AddScoped<EmailSenderService>();

builder.Services.AddScoped<AuthRepository>();
builder.Services.AddScoped<DashboardRepository>();
builder.Services.AddScoped<PatientRepository>();
builder.Services.AddScoped<CatalogRepository>();
builder.Services.AddScoped<UserRepository>();
builder.Services.AddScoped<CapacityRepository>();
builder.Services.AddScoped<AppointmentRepository>();
builder.Services.AddScoped<LoanRepository>();
builder.Services.AddScoped<ReportRepository>();

builder.Services.AddScoped<IHospitalPatientService, HospitalPatientService>();
builder.Services.AddScoped<PatientLookupService>();

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

// =============================================================
// RECUPERACIÓN DE CONTRASEÑA
// Fuerza el cambio de contraseña cuando el usuario inicia sesión
// con una contraseña temporal.
// =============================================================
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
        context.Response.Redirect("/Account/ChangePassword");
        return;
    }

    await next();
});

/// =============================================================
// REQUERIMIENTO 7
// CONTROL CENTRAL DE ACCESO POR ROLES
// =============================================================
app.Use(async (context, next) =>
{
    if (context.User.Identity?.IsAuthenticated == true)
    {
        var path = context.Request.Path;

        var isAdmin =
            context.User.IsInRole("ADMINISTRADOR");

        var isWarehouse =
            context.User.IsInRole("USUARIO_BODEGA");

        var isAppointments =
            context.User.IsInRole("USUARIO_CITAS");

        var isReports =
            context.User.IsInRole("USUARIO_INFORMES");


        // ---------------------------------------------------------
        // MÓDULOS EXCLUSIVOS DE ADMINISTRADOR Y BODEGA
        // ---------------------------------------------------------

        var isWarehouseModule =
            path.StartsWithSegments("/Inventory") ||
            path.StartsWithSegments("/Loans") ||
            path.StartsWithSegments("/Borrowers");


        // USUARIO_CITAS y USUARIO_INFORMES no pueden acceder
        // a Inventario, Préstamos ni Prestatarios.
        if (isWarehouseModule &&
            !isAdmin &&
            !isWarehouse)
        {
            context.Response.Redirect(
                "/Account/AccessDenied"
            );

            return;
        }


        // ---------------------------------------------------------
        // USUARIO_BODEGA
        // ---------------------------------------------------------

        if (isWarehouse)
        {
            var allowedForWarehouse =
                isWarehouseModule ||

                path.StartsWithSegments(
                    "/Account/Logout"
                ) ||

                path.StartsWithSegments(
                    "/Account/ChangePassword"
                ) ||

                path.StartsWithSegments(
                    "/Account/AccessDenied"
                ) ||

                path.StartsWithSegments(
                    "/Error"
                );


            // Bodega no puede entrar a ningún otro módulo.
            if (!allowedForWarehouse)
            {
                context.Response.Redirect(
                    "/Inventory/Index"
                );

                return;
            }
        }
    }

    await next();
});


app.UseAuthorization();
app.MapRazorPages();

app.Run();
