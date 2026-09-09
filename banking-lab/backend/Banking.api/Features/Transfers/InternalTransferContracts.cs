using System.Globalization;
using System.Security.Cryptography;
using System.Text;

namespace Banking.Api.Features.Transfers;

public static class InternalTransferPolicy
{
    public const long MinimumMinor = 1;
    public const long MaximumPerTransferMinor = 5_000_000;
    public const long DailyOutgoingLimitMinor = 10_000_000;
    public const string Currency = "PHP";
    public const string CompletedStatus = "COMPLETED";

    public static string Fingerprint(Guid sourceAccountReference,
        Guid destinationAccountReference, long amountMinor)
    {
        var canonical = string.Join('|',
            "internal-transfer:v1",
            sourceAccountReference.ToString("D"),
            destinationAccountReference.ToString("D"),
            Currency,
            amountMinor.ToString(CultureInfo.InvariantCulture));
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(canonical)));
    }
}

public sealed record InternalTransferRequest(
    string DestinationAccountReference,
    string AmountMinor);

public readonly record struct ValidatedInternalTransfer(
    Guid DestinationAccountReference,
    long AmountMinor);

public sealed record InternalTransferReceipt(
    Guid TransactionId,
    Guid SourceAccountReference,
    Guid DestinationAccountReference,
    string Currency,
    string AmountMinor,
    string SourceBalanceAfterMinor,
    string Status,
    DateTime CreatedAtUtc,
    bool Replayed);

public enum InternalTransferOutcome
{
    Created,
    Replayed,
    AccountNotOpened,
    RecipientNotFound,
    SelfTransferNotAllowed,
    IdempotencyConflict,
    InsufficientFunds,
    OutgoingDailyLimitReached
}

public sealed record InternalTransferResult(
    InternalTransferOutcome Outcome,
    InternalTransferReceipt? Receipt = null);
