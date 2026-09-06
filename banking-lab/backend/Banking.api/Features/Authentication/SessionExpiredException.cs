namespace Banking.Api.Features.Authentication;

// A normal authentication outcome, not an infrastructure or programming failure.
public sealed class SessionExpiredException : Exception
{
    public SessionExpiredException() : base("Session expired before access-token issuance.") { }
}
