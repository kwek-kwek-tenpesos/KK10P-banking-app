using MailKit.Security;
using Microsoft.Extensions.Options;
using MimeKit;

namespace Banking.Api.Features.Authentication;

public sealed class SmtpOptions
{
    public const string SectionName = "Smtp";

    public bool Enabled { get; set; }
    public string Host { get; set; } = string.Empty;
    public int Port { get; set; } = 587;
    public SecureSocketOptions Security { get; set; } = SecureSocketOptions.StartTls;
    public string? Username { get; set; }
    public string? Password { get; set; }
    public string FromAddress { get; set; } = string.Empty;
    public string FromName { get; set; } = "KK10P Bank";
    public string ConfirmationLinkBase { get; set; } = "kk10pbank://auth/verify-email";
    public int TimeoutSeconds { get; set; } = 10;
}

public sealed class SmtpOptionsValidator : IValidateOptions<SmtpOptions>
{
    public ValidateOptionsResult Validate(string? name, SmtpOptions options)
    {
        if (!options.Enabled) return ValidateOptionsResult.Success;

        var errors = new List<string>();
        if (string.IsNullOrWhiteSpace(options.Host) || options.Host.Length > 253)
            errors.Add("Smtp:Host is required and must be at most 253 characters.");
        if (options.Port is < 1 or > 65535)
            errors.Add("Smtp:Port must be between 1 and 65535.");
        if (options.TimeoutSeconds is < 1 or > 60)
            errors.Add("Smtp:TimeoutSeconds must be between 1 and 60.");
        if (string.IsNullOrWhiteSpace(options.FromName) || options.FromName.Length > 100)
            errors.Add("Smtp:FromName is required and must be at most 100 characters.");
        if (!MailboxAddress.TryParse(options.FromAddress, out _))
            errors.Add("Smtp:FromAddress must be a valid mailbox address.");

        var hasUsername = !string.IsNullOrWhiteSpace(options.Username);
        var hasPassword = !string.IsNullOrEmpty(options.Password);
        if (hasUsername != hasPassword)
            errors.Add("Smtp:Username and Smtp:Password must either both be configured or both be absent.");

        if (options.Security is not (
                SecureSocketOptions.None or
                SecureSocketOptions.StartTls or
                SecureSocketOptions.SslOnConnect))
        {
            errors.Add("Smtp:Security must be None, StartTls, or SslOnConnect.");
        }

        var isLoopbackHost = options.Host.Equals("localhost", StringComparison.OrdinalIgnoreCase)
            || options.Host is "127.0.0.1" or "::1";
        if (!isLoopbackHost && options.Security == SecureSocketOptions.None)
            errors.Add("Unencrypted SMTP is permitted only for a loopback development mailbox.");

        if (!Uri.TryCreate(options.ConfirmationLinkBase, UriKind.Absolute, out var link)
            || link.Scheme != "kk10pbank"
            || !string.Equals(link.Host, "auth", StringComparison.OrdinalIgnoreCase)
            || link.AbsolutePath != "/verify-email"
            || !string.IsNullOrEmpty(link.Query)
            || !string.IsNullOrEmpty(link.Fragment)
            || !string.IsNullOrEmpty(link.UserInfo))
        {
            errors.Add("Smtp:ConfirmationLinkBase must be exactly the KK10P Bank verification route without query or fragment data.");
        }

        return errors.Count == 0
            ? ValidateOptionsResult.Success
            : ValidateOptionsResult.Fail(errors);
    }
}
