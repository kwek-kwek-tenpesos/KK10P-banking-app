using System.Net;
using System.Net.Http.Json;
using Banking.Api.Features.Authentication;
using MailKit.Security;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace Banking.IntegrationTests;

public sealed class CustomerEmailVerificationTests
{
    private const string Email = "verify@example.test";
    private const string Password = "Correct horse battery staple 47";

    [Fact]
    public async Task Delivery_CreatesAppLink_ThatConfirmsExactlyOnce()
    {
        using var host = new RegistrationTestHost();
        var user = await CreateUnconfirmedUserAsync(host, Email);
        var sender = new RecordingEmailSender();
        var options = Options.Create(EnabledLoopbackOptions());

        using (var scope = host.Services.CreateScope())
        {
            var delivery = new CustomerVerificationDelivery(
                scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>(),
                sender,
                options,
                NullLogger<CustomerVerificationDelivery>.Instance);

            Assert.True(await delivery.TryDeliverAsync(user.Id, CancellationToken.None));
        }

        var message = Assert.Single(sender.Messages);
        Assert.Equal(Email, message.Recipient);
        var link = new Uri(message.ConfirmationLink);
        Assert.Equal("kk10pbank", link.Scheme);
        Assert.Equal("auth", link.Host);
        Assert.Equal("/verify-email", link.AbsolutePath);
        var parameters = ParseQuery(link.Query);

        using var client = host.CreateClient();
        using var first = await client.PostAsJsonAsync("/api/v1/auth/verify-email", new
        {
            userId = parameters["userId"],
            token = parameters["token"]
        });
        Assert.Equal(HttpStatusCode.NoContent, first.StatusCode);
        Assert.True(user.EmailConfirmed);

        using var replay = await client.PostAsJsonAsync("/api/v1/auth/verify-email", new
        {
            userId = parameters["userId"],
            token = parameters["token"]
        });
        Assert.Equal(HttpStatusCode.BadRequest, replay.StatusCode);
    }

    [Fact]
    public async Task Resend_ReturnsSameAcceptedResponse_ForKnownAndUnknownEmail()
    {
        using var host = new RegistrationTestHost();
        var user = await CreateUnconfirmedUserAsync(host, Email);
        using var client = host.CreateClient();

        using var known = await client.PostAsJsonAsync(
            "/api/v1/auth/resend-verification",
            new { email = Email });
        using var unknown = await client.PostAsJsonAsync(
            "/api/v1/auth/resend-verification",
            new { email = "missing@example.test" });

        Assert.Equal(HttpStatusCode.Accepted, known.StatusCode);
        Assert.Equal(HttpStatusCode.Accepted, unknown.StatusCode);
        Assert.Equal(await known.Content.ReadAsStringAsync(), await unknown.Content.ReadAsStringAsync());
        Assert.Equal([user.Id], host.Delivery.RequestedUserIds);
    }

    [Fact]
    public async Task Resend_WhenDeliveryIsDisabled_ReturnsServiceUnavailable()
    {
        using var host = new RegistrationTestHost();
        host.Delivery.IsConfigured = false;
        using var client = host.CreateClient();

        using var response = await client.PostAsJsonAsync(
            "/api/v1/auth/resend-verification",
            new { email = "missing@example.test" });

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
    }

    [Theory]
    [InlineData(false, "smtp.example.test", SecureSocketOptions.None, true)]
    [InlineData(true, "localhost", SecureSocketOptions.None, true)]
    [InlineData(true, "smtp.example.test", SecureSocketOptions.StartTls, true)]
    public void SmtpOptions_EnforceSecureRemoteTransport(
        bool enabled,
        string host,
        SecureSocketOptions security,
        bool expectedValid)
    {
        var options = EnabledLoopbackOptions();
        options.Enabled = enabled;
        options.Host = host;
        options.Security = security;

        var result = new SmtpOptionsValidator().Validate(null, options);

        Assert.Equal(expectedValid, result.Succeeded);
    }

    [Fact]
    public void SmtpOptions_RejectPartialCredentials_AndWrongAppLink()
    {
        var options = EnabledLoopbackOptions();
        options.Username = "sender";
        options.ConfirmationLinkBase = "https://example.test/verify-email";

        var result = new SmtpOptionsValidator().Validate(null, options);

        Assert.False(result.Succeeded);
        Assert.Contains(result.Failures!, failure => failure.Contains("both be configured"));
        Assert.Contains(result.Failures!, failure => failure.Contains("KK10P Bank verification route"));
    }

    private static async Task<ApplicationUser> CreateUnconfirmedUserAsync(
        RegistrationTestHost host,
        string email)
    {
        using var scope = host.Services.CreateScope();
        var users = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var user = new ApplicationUser
        {
            Email = email,
            UserName = users.NormalizeEmail(email),
            EmailConfirmed = false,
            IsEnabled = true,
            LockoutEnabled = true
        };
        var result = await users.CreateAsync(user, Password);
        Assert.True(result.Succeeded, string.Join(", ", result.Errors.Select(error => error.Code)));
        return user;
    }

    private static Dictionary<string, string> ParseQuery(string query) => query
        .TrimStart('?')
        .Split('&', StringSplitOptions.RemoveEmptyEntries)
        .Select(part => part.Split('=', 2))
        .ToDictionary(
            part => Uri.UnescapeDataString(part[0]),
            part => Uri.UnescapeDataString(part[1]));

    private static SmtpOptions EnabledLoopbackOptions() => new()
    {
        Enabled = true,
        Host = "localhost",
        Port = 1025,
        Security = SecureSocketOptions.None,
        FromAddress = "noreply@kk10p.test",
        FromName = "KK10P Bank",
        ConfirmationLinkBase = "kk10pbank://auth/verify-email",
        TimeoutSeconds = 5
    };

    private sealed class RecordingEmailSender : IVerificationEmailSender
    {
        public List<VerificationEmailMessage> Messages { get; } = [];

        public Task SendAsync(VerificationEmailMessage message, CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            Messages.Add(message);
            return Task.CompletedTask;
        }
    }
}
