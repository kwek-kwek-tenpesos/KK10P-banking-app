using System.Text;
using Banking.Api.Features.Accounts;
using banking_lab.infrastructure.temporary;
using Banking.Api.Features.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

// Register your AppDbContext using the connection string configuration key
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddSingleton<IValidateOptions<JwtOptions>, JwtOptionsValidator>();
builder.Services.AddOptions<JwtOptions>()
    .Bind(builder.Configuration.GetSection(JwtOptions.SectionName)).ValidateOnStart();
builder.Services.AddSingleton<IValidateOptions<SmtpOptions>, SmtpOptionsValidator>();
builder.Services.AddOptions<SmtpOptions>()
    .Bind(builder.Configuration.GetSection(SmtpOptions.SectionName)).ValidateOnStart();
builder.Services.AddTrustedLoopbackForwarding();
builder.Services.AddAuthenticationRequestGuards();
builder.Services.AddAccountRequestGuards();
builder.Services.AddScoped<CustomerAccountService>();
builder.Services.AddSingleton<ICustomerPasswordBlocklist, InitialCustomerPasswordBlocklist>();
builder.Services.AddSingleton<CustomerPasswordPolicy>();
builder.Services.AddSingleton<IVerificationEmailSender, SmtpVerificationEmailSender>();
builder.Services.AddScoped<ICustomerVerificationDelivery, CustomerVerificationDelivery>();
builder.Services.AddSingleton<ITokenService, TokenService>();
builder.Services.AddScoped<CustomerRegistrationService>();
builder.Services.AddScoped<CustomerEmailVerificationService>();
builder.Services.AddScoped<CustomerLoginService>();
builder.Services.AddScoped<CustomerSessionService>();
builder.Services.AddScoped<SessionBearerEvents>();

// Register user/password and lockout services
builder.Services.AddIdentityCore<ApplicationUser>(options =>
    {
        options.User.RequireUniqueEmail = true;
        // CustomerUserValidator requires an email-derived login name instead.
        options.User.AllowedUserNameCharacters = string.Empty;
        // CustomerPasswordValidator applies the code-point and blocklist rules.
        options.Password.RequiredLength = 1;
        options.Password.RequiredUniqueChars = 1;
        options.Password.RequireDigit = false;
        options.Password.RequireLowercase = false;
        options.Password.RequireNonAlphanumeric = false;
        options.Password.RequireUppercase = false;

        // Anti-brute-force lockout policy
        options.Lockout.AllowedForNewUsers = true;
        options.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(5);
        options.Lockout.MaxFailedAccessAttempts = 5;
    })
    .AddEntityFrameworkStores<AppDbContext>()
    .AddUserValidator<CustomerUserValidator>()
    .AddPasswordValidator<CustomerPasswordValidator>()
    .AddDefaultTokenProviders();
builder.Services.Configure<DataProtectionTokenProviderOptions>(options =>
    options.TokenLifespan = TimeSpan.FromHours(1));

builder.Services.AddAuthentication(options =>
    {
        options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
        options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
    })
    .AddJwtBearer();
builder.Services.AddOptions<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme)
    .Configure<IOptions<JwtOptions>>((options, configured) =>
    {
        var jwtOptions = configured.Value;
        var signingKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtOptions.SigningKey));
        options.RequireHttpsMetadata = true;
        options.SaveToken = false;
        options.EventsType = typeof(SessionBearerEvents);
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = signingKey,
            ValidateIssuer = true,
            ValidIssuer = jwtOptions.Issuer,
            ValidateAudience = true,
            ValidAudience = jwtOptions.Audience,
            ValidateLifetime = true,
            ValidAlgorithms = [SecurityAlgorithms.HmacSha256],
            ClockSkew = TimeSpan.Zero
        };
    });

builder.Services.AddAuthorization();
builder.Services.AddOpenApi();

var app = builder.Build();

// Tailscale Serve terminates TLS and proxies only to this machine's loopback
// listener. Unknown callers cannot turn an HTTP request into HTTPS by adding a
// forwarded header because only exact loopback proxy addresses are trusted.
app.UseForwardedHeaders();

app.Use(async (context, next) =>
{
    context.Response.Headers.Append("X-Content-Type-Options", "nosniff");
    context.Response.Headers.Append("X-Frame-Options", "DENY");
    context.Response.Headers.Append("Referrer-Policy", "strict-origin-when-cross-origin");
    context.Response.Headers.Append("X-Permitted-Cross-Domain-Policies", "none");
    await next();
});

app.UseRouting();
// Ensure even throttled auth responses cannot be cached.
app.Use(async (context, next) =>
{
    if (context.Request.Path.StartsWithSegments("/api/v1/auth"))
        context.Response.Headers.CacheControl = "no-store";
    await next();
});
app.Use(AccountRequestGuards.EnforceTransportAsync);
app.UseRateLimiter();
app.Use(AccountRequestGuards.EnforceInputAsync);
app.Use(AuthenticationRequestGuards.EnforceAsync);
app.UseAuthentication();
app.UseAuthorization();

if (app.Environment.IsDevelopment() || app.Environment.EnvironmentName == "Testing")
{
    app.MapOpenApi();
}

app.MapGet("/api/v1/system/info", (IWebHostEnvironment env) =>
    Results.Ok(new
    {
        name = "Banking API",
        version = "v1.0.0",
        environment = env.EnvironmentName
    }));

app.MapPost("/api/v1/auth/register", async (
    CustomerRegistrationRequest request,
    CustomerRegistrationService registrationService,
    CancellationToken cancellationToken) =>
{
    var result = await registrationService.RegisterAsync(request, cancellationToken);
    return result.Outcome switch
    {
        CustomerRegistrationOutcome.Accepted => Results.Accepted(uri: null, value: result),
        CustomerRegistrationOutcome.Invalid => Results.ValidationProblem(
            errors: new Dictionary<string, string[]>(result.Errors),
            detail: result.Message,
            statusCode: StatusCodes.Status400BadRequest),
        CustomerRegistrationOutcome.Unavailable => Results.Problem(
            detail: result.Message,
            statusCode: StatusCodes.Status503ServiceUnavailable),
        _ => Results.StatusCode(StatusCodes.Status500InternalServerError)
    };
})
.WithName("RegisterCustomer")
.RequireRateLimiting("register")
.ProducesProblem(StatusCodes.Status413PayloadTooLarge)
.ProducesProblem(StatusCodes.Status429TooManyRequests)
.Produces<CustomerRegistrationResult>(StatusCodes.Status202Accepted)
.ProducesValidationProblem(StatusCodes.Status400BadRequest)
.ProducesProblem(StatusCodes.Status503ServiceUnavailable);

app.MapPost("/api/v1/auth/verify-email", async (
    CustomerEmailConfirmationRequest request,
    CustomerEmailVerificationService verificationService,
    CancellationToken cancellationToken) =>
{
    var result = await verificationService.ConfirmAsync(request, cancellationToken);
    return result switch
    {
        CustomerEmailConfirmationOutcome.Confirmed => Results.NoContent(),
        CustomerEmailConfirmationOutcome.Invalid => Results.Problem(
            detail: "The verification link is invalid or expired.",
            statusCode: StatusCodes.Status400BadRequest,
            title: "Invalid verification"),
        CustomerEmailConfirmationOutcome.Unavailable => Results.Problem(
            detail: "Email verification is temporarily unavailable. Please try again later.",
            statusCode: StatusCodes.Status503ServiceUnavailable,
            title: "Service Unavailable"),
        _ => Results.StatusCode(StatusCodes.Status500InternalServerError)
    };
})
.WithName("VerifyCustomerEmail")
.RequireRateLimiting("verify-email")
.Produces(StatusCodes.Status204NoContent)
.ProducesProblem(StatusCodes.Status400BadRequest)
.ProducesProblem(StatusCodes.Status413PayloadTooLarge)
.ProducesProblem(StatusCodes.Status429TooManyRequests)
.ProducesProblem(StatusCodes.Status503ServiceUnavailable);

app.MapPost("/api/v1/auth/resend-verification", async (
    CustomerVerificationResendRequest request,
    CustomerEmailVerificationService verificationService,
    CancellationToken cancellationToken) =>
{
    var result = await verificationService.ResendAsync(request, cancellationToken);
    return result.Outcome switch
    {
        CustomerVerificationResendOutcome.Accepted => Results.Accepted(uri: null, value: result),
        CustomerVerificationResendOutcome.Unavailable => Results.Problem(
            detail: result.Message,
            statusCode: StatusCodes.Status503ServiceUnavailable,
            title: "Service Unavailable"),
        _ => Results.StatusCode(StatusCodes.Status500InternalServerError)
    };
})
.WithName("ResendCustomerVerification")
.RequireRateLimiting("resend-verification")
.Produces<CustomerVerificationResendResult>(StatusCodes.Status202Accepted)
.ProducesProblem(StatusCodes.Status413PayloadTooLarge)
.ProducesProblem(StatusCodes.Status429TooManyRequests)
.ProducesProblem(StatusCodes.Status503ServiceUnavailable);

app.MapPost("/api/v1/auth/login", async (
    CustomerLoginRequest request,
    CustomerLoginService loginService,
    CancellationToken cancellationToken) =>
{
    var result = await loginService.LoginAsync(request, cancellationToken);
    return result.Outcome switch
    {
        CustomerLoginOutcome.Success => Results.Ok(result.Response),
        CustomerLoginOutcome.InvalidCredentials or CustomerLoginOutcome.LockedOut => Results.Problem(
            detail: "Invalid email or password.",
            statusCode: StatusCodes.Status401Unauthorized,
            title: "Unauthorized"),
        CustomerLoginOutcome.Unavailable => Results.Problem(
            detail: result.Message,
            statusCode: StatusCodes.Status503ServiceUnavailable,
            title: "Service Unavailable"),
        _ => Results.StatusCode(StatusCodes.Status500InternalServerError)
    };
})
.WithName("LoginCustomer")
.RequireRateLimiting("login")
.ProducesProblem(StatusCodes.Status400BadRequest)
.ProducesProblem(StatusCodes.Status413PayloadTooLarge)
.ProducesProblem(StatusCodes.Status429TooManyRequests)
.Produces<CustomerLoginResponse>(StatusCodes.Status200OK)
.ProducesProblem(StatusCodes.Status401Unauthorized)
.ProducesProblem(StatusCodes.Status503ServiceUnavailable);

app.MapPost("/api/v1/auth/refresh", async (
    TokenRefreshRequest request,
    CustomerLoginService loginService,
    HttpContext context,
    CancellationToken cancellationToken) =>
{
    var result = await loginService.RefreshAsync(request, cancellationToken);
    if (result.Outcome == TokenRefreshOutcome.RateLimited)
    {
        context.Response.Headers.RetryAfter = "60";
        return Results.Problem(statusCode: 429, detail: result.Message);
    }
    return result.Outcome switch
    {
        TokenRefreshOutcome.Success => Results.Ok(result.Response),
        TokenRefreshOutcome.InvalidToken => Results.Problem(
            detail: result.Message,
            statusCode: StatusCodes.Status401Unauthorized,
            title: "Unauthorized"),
        TokenRefreshOutcome.TokenCompromised => Results.Problem(
            detail: result.Message,
            statusCode: StatusCodes.Status401Unauthorized,
            title: "Unauthorized"),
        TokenRefreshOutcome.Unavailable => Results.Problem(
            detail: result.Message,
            statusCode: StatusCodes.Status503ServiceUnavailable,
            title: "Service Unavailable"),
        _ => Results.StatusCode(StatusCodes.Status500InternalServerError)
    };
})
.WithName("RefreshToken")
.RequireRateLimiting("refresh")
.ProducesProblem(StatusCodes.Status400BadRequest)
.ProducesProblem(StatusCodes.Status413PayloadTooLarge)
.ProducesProblem(StatusCodes.Status429TooManyRequests)
.Produces<CustomerLoginResponse>(StatusCodes.Status200OK)
.ProducesProblem(StatusCodes.Status401Unauthorized)
.ProducesProblem(StatusCodes.Status503ServiceUnavailable);

app.MapPost("/api/v1/auth/logout", async (
    TokenRevocationRequest request,
    CustomerLoginService loginService,
    CancellationToken cancellationToken) =>
{
    if (string.IsNullOrWhiteSpace(request.RefreshToken) || request.RefreshToken.Length > 512)
        return Results.Problem(statusCode: 400, detail: "Provide a valid refresh token.");
    return await loginService.LogoutAsync(request, cancellationToken)
        ? Results.NoContent()
        : Results.Problem(statusCode: 503, detail: "Server logout could not be confirmed. Please try again.");
})
.WithName("LogoutCustomer")
.RequireRateLimiting("logout")
.ProducesProblem(StatusCodes.Status413PayloadTooLarge)
.ProducesProblem(StatusCodes.Status429TooManyRequests)
.Produces(StatusCodes.Status204NoContent)
.ProducesProblem(StatusCodes.Status400BadRequest)
.ProducesProblem(StatusCodes.Status503ServiceUnavailable);

app.MapGet("/api/v1/auth/me", (HttpContext context) =>
{
    var user = context.Items[typeof(ApplicationUser)] as ApplicationUser;
    return user is null ? Results.Unauthorized() : Results.Ok(new { user.Id, user.DisplayName });
}).RequireAuthorization().WithName("CurrentCustomer")
    .Produces(StatusCodes.Status200OK).ProducesProblem(401).ProducesProblem(503);

app.MapCustomerAccounts();
app.Run();

public partial class Program { }
