using System.Globalization;
using System.Security.Cryptography;

namespace Banking.Api.Features.Ledger;

public static class DevelopmentFundingPolicy
{
    public const long GrantMinor = 5_000_000;
    public const long DailyLimitMinor = 10_000_000;
    public const string Currency = "PHP";
    public const string TimeZoneId = "Asia/Manila";
    public static readonly string RequestFingerprint = Convert.ToHexString(
        SHA256.HashData("development-funding:v1:PHP:5000000"u8));
}

public sealed record DevelopmentFundingReceipt(
    Guid TransactionId,
    Guid AccountId,
    string Currency,
    string CreditedAmountMinor,
    string BalanceAfterMinor,
    DateTime CreatedAtUtc,
    bool Replayed)
{
    public static DevelopmentFundingReceipt From(
        LedgerTransaction transaction,
        Guid accountId,
        bool replayed) => new(
            transaction.Id,
            accountId,
            transaction.Currency,
            DevelopmentFundingPolicy.GrantMinor.ToString(CultureInfo.InvariantCulture),
            transaction.BalanceAfterMinor.ToString(CultureInfo.InvariantCulture),
            transaction.CreatedAtUtc,
            replayed);
}

public enum DevelopmentFundingOutcome
{
    Created,
    Replayed,
    AccountNotOpened,
    DailyLimitReached,
    IdempotencyConflict
}

public sealed record DevelopmentFundingResult(
    DevelopmentFundingOutcome Outcome,
    DevelopmentFundingReceipt? Receipt = null);

public readonly record struct BusinessDayRange(DateTime StartUtc, DateTime EndUtc);

public static class PhilippineBusinessDay
{
    private static readonly TimeZoneInfo Zone = TimeZoneInfo.FindSystemTimeZoneById(
        DevelopmentFundingPolicy.TimeZoneId);

    public static BusinessDayRange For(DateTimeOffset utcNow)
    {
        var localDate = TimeZoneInfo.ConvertTime(utcNow, Zone).Date;
        var nextDate = localDate.AddDays(1);
        return new(
            TimeZoneInfo.ConvertTimeToUtc(DateTime.SpecifyKind(localDate, DateTimeKind.Unspecified), Zone),
            TimeZoneInfo.ConvertTimeToUtc(DateTime.SpecifyKind(nextDate, DateTimeKind.Unspecified), Zone));
    }
}
