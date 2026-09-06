using System.Text;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.WebUtilities;

namespace Banking.Api.Features.Authentication;

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class CustomerEmailConfirmationRequest
{
    public string? UserId { get; init; }
    public string? Token { get; init; }

    public override string ToString() => "CustomerEmailConfirmationRequest { Redacted }";
}

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class CustomerVerificationResendRequest
{
    public string? Email { get; init; }

    public override string ToString() => "CustomerVerificationResendRequest { Redacted }";
}

public enum CustomerEmailConfirmationOutcome
{
    Confirmed,
    Invalid,
    Unavailable
}

public enum CustomerVerificationResendOutcome
{
    Accepted,
    Unavailable
}

public sealed record CustomerVerificationResendResult(
    CustomerVerificationResendOutcome Outcome,
    string Message)
{
    public static CustomerVerificationResendResult Accepted() => new(
        CustomerVerificationResendOutcome.Accepted,
        "If the account can be verified, a new confirmation message will be sent.");

    public static CustomerVerificationResendResult Unavailable() => new(
        CustomerVerificationResendOutcome.Unavailable,
        "Email verification is temporarily unavailable. Please try again later.");
}

public sealed class CustomerEmailVerificationService(
    UserManager<ApplicationUser> users,
    ICustomerVerificationDelivery delivery,
    ILogger<CustomerEmailVerificationService> logger)
{
    public async Task<CustomerEmailConfirmationOutcome> ConfirmAsync(
        CustomerEmailConfirmationRequest request,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(request);
        cancellationToken.ThrowIfCancellationRequested();

        if (string.IsNullOrWhiteSpace(request.UserId)
            || request.UserId.Length > 450
            || string.IsNullOrWhiteSpace(request.Token)
            || request.Token.Length > 8192)
        {
            return CustomerEmailConfirmationOutcome.Invalid;
        }

        string token;
        try
        {
            token = Encoding.UTF8.GetString(WebEncoders.Base64UrlDecode(request.Token));
        }
        catch (FormatException)
        {
            return CustomerEmailConfirmationOutcome.Invalid;
        }

        try
        {
            var user = await users.FindByIdAsync(request.UserId);
            if (user is null || !user.IsEnabled || user.EmailConfirmed)
                return CustomerEmailConfirmationOutcome.Invalid;

            var result = await users.ConfirmEmailAsync(user, token);
            return result.Succeeded
                ? CustomerEmailConfirmationOutcome.Confirmed
                : CustomerEmailConfirmationOutcome.Invalid;
        }
        catch (Exception exception) when (AuthenticationDependencyFailure.Is(exception))
        {
            logger.LogWarning("Customer email confirmation persistence failed.");
            return CustomerEmailConfirmationOutcome.Unavailable;
        }
    }

    public async Task<CustomerVerificationResendResult> ResendAsync(
        CustomerVerificationResendRequest request,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(request);
        cancellationToken.ThrowIfCancellationRequested();

        if (!delivery.IsConfigured)
            return CustomerVerificationResendResult.Unavailable();

        var email = request.Email?.Trim();
        if (string.IsNullOrWhiteSpace(email) || email.Length > ApplicationUser.MaximumEmailLength)
            return CustomerVerificationResendResult.Accepted();

        try
        {
            var user = await users.FindByEmailAsync(email);
            if (user is { IsEnabled: true, EmailConfirmed: false })
                _ = await delivery.TryDeliverAsync(user.Id, cancellationToken);

            return CustomerVerificationResendResult.Accepted();
        }
        catch (ArgumentException)
        {
            return CustomerVerificationResendResult.Accepted();
        }
        catch (Exception exception) when (AuthenticationDependencyFailure.Is(exception))
        {
            logger.LogWarning("Customer verification resend lookup failed.");
            return CustomerVerificationResendResult.Unavailable();
        }
    }
}
