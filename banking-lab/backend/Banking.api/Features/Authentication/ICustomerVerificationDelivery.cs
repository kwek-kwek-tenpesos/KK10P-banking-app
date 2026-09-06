namespace Banking.Api.Features.Authentication;

// The future implementation owns purpose/expiry/generation/retry rules and
// delivers the credential through the approved email flow, never the API result.
// It receives only an internal user ID, not an entity containing password hashes.
public interface ICustomerVerificationDelivery
{
    bool IsConfigured { get; }

    // False means an expected delivery failure, not that the user is confirmed.
    // Cancellation propagates; implementations must not log credentials.
    Task<bool> TryDeliverAsync(string userId, CancellationToken cancellationToken);
}

// Fail closed until verification storage, transport and delivery are implemented.
public sealed class UnconfiguredCustomerVerificationDelivery : ICustomerVerificationDelivery
{
    public bool IsConfigured => false;

    public Task<bool> TryDeliverAsync(string userId, CancellationToken cancellationToken) =>
        Task.FromResult(false);
}
