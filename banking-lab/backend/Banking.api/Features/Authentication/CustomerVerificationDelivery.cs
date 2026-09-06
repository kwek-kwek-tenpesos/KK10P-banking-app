using System.Net;
using System.Net.Sockets;
using System.Security.Authentication;
using System.Text;
using MailKit;
using MailKit.Net.Smtp;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.Extensions.Options;
using MimeKit;

namespace Banking.Api.Features.Authentication;

public sealed record VerificationEmailMessage(string Recipient, string ConfirmationLink);

public interface IVerificationEmailSender
{
    Task SendAsync(VerificationEmailMessage message, CancellationToken cancellationToken);
}

public sealed class SmtpVerificationEmailSender(IOptions<SmtpOptions> configured) : IVerificationEmailSender
{
    private readonly SmtpOptions _options = configured.Value;

    public async Task SendAsync(VerificationEmailMessage message, CancellationToken cancellationToken)
    {
        var email = new MimeMessage();
        email.From.Add(new MailboxAddress(_options.FromName, _options.FromAddress));
        email.To.Add(MailboxAddress.Parse(message.Recipient));
        email.Subject = "Confirm your KK10P Bank simulator account";
        email.Body = new TextPart("plain")
        {
            Text = "Confirm your fake-money KK10P Bank account by opening this one-use link:\n\n"
                + message.ConfirmationLink
                + "\n\nIf you did not request this account, ignore this message."
        };

        using var client = new SmtpClient { Timeout = _options.TimeoutSeconds * 1000 };
        await client.ConnectAsync(
            _options.Host,
            _options.Port,
            _options.Security,
            cancellationToken);

        try
        {
            if (!string.IsNullOrWhiteSpace(_options.Username))
                await client.AuthenticateAsync(_options.Username, _options.Password!, cancellationToken);

            await client.SendAsync(email, cancellationToken);
        }
        finally
        {
            if (client.IsConnected)
                await client.DisconnectAsync(true, cancellationToken);
        }
    }
}

public sealed class CustomerVerificationDelivery(
    UserManager<ApplicationUser> users,
    IVerificationEmailSender sender,
    IOptions<SmtpOptions> configured,
    ILogger<CustomerVerificationDelivery> logger) : ICustomerVerificationDelivery
{
    private readonly SmtpOptions _options = configured.Value;

    public bool IsConfigured => _options.Enabled;

    public async Task<bool> TryDeliverAsync(string userId, CancellationToken cancellationToken)
    {
        if (!IsConfigured) return false;

        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(TimeSpan.FromSeconds(_options.TimeoutSeconds));

        try
        {
            var user = await users.FindByIdAsync(userId);
            if (user is null || user.EmailConfirmed || string.IsNullOrWhiteSpace(user.Email))
                return false;

            var token = await users.GenerateEmailConfirmationTokenAsync(user);
            var encodedToken = WebEncoders.Base64UrlEncode(Encoding.UTF8.GetBytes(token));
            var link = QueryHelpers.AddQueryString(
                _options.ConfirmationLinkBase,
                new Dictionary<string, string?>
                {
                    ["userId"] = user.Id,
                    ["token"] = encodedToken
                });

            await sender.SendAsync(
                new VerificationEmailMessage(user.Email, link),
                timeout.Token);
            return true;
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            logger.LogWarning("Customer verification delivery timed out.");
            return false;
        }
        catch (Exception exception) when (IsExpectedFailure(exception))
        {
            logger.LogWarning("Customer verification delivery failed.");
            return false;
        }
    }

    private static bool IsExpectedFailure(Exception exception) =>
        AuthenticationDependencyFailure.Is(exception)
        || exception is IOException or SocketException or AuthenticationException
        || exception is MailKit.ProtocolException or MailKit.CommandException or TimeoutException;
}
