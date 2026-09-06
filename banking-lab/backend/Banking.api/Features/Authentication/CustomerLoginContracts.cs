using System.Text.Json.Serialization;

namespace Banking.Api.Features.Authentication;

// Input only: never serialize this object into a response or log its properties.
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class CustomerLoginRequest
{
    public string? Email { get; init; }
    public string? Password { get; init; }

    public override string ToString() => "CustomerLoginRequest { Redacted }";
}

// Credentials returned only upon successful verification.
public sealed record CustomerLoginResponse(
    string AccessToken,
    string RefreshToken,
    string TokenType,
    int ExpiresInSeconds)
{
    public override string ToString() => "CustomerLoginResponse { Redacted }";
}

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class TokenRefreshRequest
{
    public string? RefreshToken { get; init; }

    public override string ToString() => "TokenRefreshRequest { Redacted }";
}

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class TokenRevocationRequest
{
    public string? RefreshToken { get; init; }

    public override string ToString() => "TokenRevocationRequest { Redacted }";
}

public enum CustomerLoginOutcome
{
    Success,
    InvalidCredentials,
    LockedOut,
    Unavailable
}

public sealed record CustomerLoginResult(
    CustomerLoginOutcome Outcome,
    string Message,
    CustomerLoginResponse? Response = null,
    IReadOnlyDictionary<string, string[]>? Errors = null)
{
    public static CustomerLoginResult Success(CustomerLoginResponse response) => new(
        CustomerLoginOutcome.Success,
        "Login successful.",
        response,
        new Dictionary<string, string[]>());

    public static CustomerLoginResult InvalidCredentials(string message = "Invalid email or password.") => new(
        CustomerLoginOutcome.InvalidCredentials,
        message,
        null,
        new Dictionary<string, string[]>());

    public static CustomerLoginResult InvalidInput(Dictionary<string, string[]> errors) => new(
        CustomerLoginOutcome.InvalidCredentials,
        "Check the login fields and try again.",
        null,
        errors);

    public static CustomerLoginResult LockedOut(
        string message = "Account is temporarily locked due to multiple failed login attempts. Please try again later.") => new(
        CustomerLoginOutcome.LockedOut,
        message,
        null,
        new Dictionary<string, string[]>());

    public static CustomerLoginResult Unavailable(
        string message = "Authentication is temporarily unavailable. Please try again later.") => new(
        CustomerLoginOutcome.Unavailable,
        message,
        null,
        new Dictionary<string, string[]>());
}

public enum TokenRefreshOutcome
{
    Success,
    RateLimited,
    InvalidToken,
    TokenCompromised,
    Unavailable
}

public sealed record TokenRefreshResult(
    TokenRefreshOutcome Outcome,
    string Message,
    CustomerLoginResponse? Response = null)
{
    public static TokenRefreshResult RateLimited() => new(TokenRefreshOutcome.RateLimited, "Try again later.");
    public static TokenRefreshResult Success(CustomerLoginResponse response) => new(
        TokenRefreshOutcome.Success,
        "Token refreshed successfully.",
        response);

    public static TokenRefreshResult InvalidToken(string message = "Invalid or expired refresh token.") => new(
        TokenRefreshOutcome.InvalidToken,
        message);

    public static TokenRefreshResult TokenCompromised(
        string message = "Token compromise detected. Session terminated.") => new(
        TokenRefreshOutcome.TokenCompromised,
        message);

    public static TokenRefreshResult Unavailable(
        string message = "Token refresh is temporarily unavailable. Please try again later.") => new(
        TokenRefreshOutcome.Unavailable,
        message);
}
