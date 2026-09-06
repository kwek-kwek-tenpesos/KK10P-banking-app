using System.Text.Json.Serialization;

namespace Banking.Api.Features.Authentication;

// Input only: never serialize this object into a response or log its properties.
// Do not bind public input directly to ApplicationUser.
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class CustomerRegistrationRequest
{
    public string? Email { get; init; }
    public string? Password { get; init; }
    public string? DisplayName { get; init; }

    public override string ToString() => "CustomerRegistrationRequest { Redacted }";
}

public enum CustomerRegistrationOutcome
{
    Accepted,
    Invalid,
    Unavailable
}

// Service result only. A future HTTP adapter maps these outcomes to 202/400/503
// and Problem Details; no user, account-existence flag or credential is returned.
public sealed record CustomerRegistrationResult(
    CustomerRegistrationOutcome Outcome,
    string Message,
    IReadOnlyDictionary<string, string[]> Errors)
{
    public static CustomerRegistrationResult Accepted() => new(
        CustomerRegistrationOutcome.Accepted,
        "If registration can proceed, check your email for the next step.",
        new Dictionary<string, string[]>());

    public static CustomerRegistrationResult Invalid(Dictionary<string, string[]> errors) => new(
        CustomerRegistrationOutcome.Invalid,
        "Check the registration fields and try again.",
        errors);

    public static CustomerRegistrationResult Unavailable() => new(
        CustomerRegistrationOutcome.Unavailable,
        "Registration is temporarily unavailable. Please try again later.",
        new Dictionary<string, string[]>());
}
