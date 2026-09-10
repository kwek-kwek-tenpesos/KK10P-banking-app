using System.Buffers.Binary;
using System.Globalization;
using Microsoft.AspNetCore.WebUtilities;

namespace Banking.Api.Features.Activity;

public static class ActivityPolicy
{
    public const int DefaultPageSize = 20;
    public const int MaximumPageSize = 50;
    public const int MaximumCursorLength = 64;
    public const string Incoming = "INCOMING";
    public const string Outgoing = "OUTGOING";
    public const string Completed = "COMPLETED";
    public const string Kk10pAccount = "KK10P_ACCOUNT";
    public const string SimulatorIssuer = "SIMULATOR_ISSUER";

    private static readonly HashSet<string> AllowedQueryNames =
        ["limit", "cursor", "direction", "type"];

    public static bool TryParseQuery(
        IQueryCollection query,
        out ActivityQuery parsed,
        out string detail)
    {
        parsed = new ActivityQuery(DefaultPageSize, null, null, null);
        detail = "Provide only valid Activity pagination and filter parameters.";

        if (query.Keys.Any(key => !AllowedQueryNames.Contains(key)) ||
            query.Any(item => item.Value.Count != 1 || string.IsNullOrEmpty(item.Value[0])))
            return false;

        var limit = DefaultPageSize;
        if (query.TryGetValue("limit", out var limitValues) &&
            (!int.TryParse(limitValues[0], NumberStyles.None, CultureInfo.InvariantCulture, out limit) ||
             limit is < 1 or > MaximumPageSize ||
             !string.Equals(limitValues[0], limit.ToString(CultureInfo.InvariantCulture), StringComparison.Ordinal)))
        {
            detail = $"limit must be a canonical integer from 1 through {MaximumPageSize}.";
            return false;
        }

        string? direction = null;
        if (query.TryGetValue("direction", out var directionValues))
        {
            direction = directionValues[0];
            if (direction is not (Incoming or Outgoing))
            {
                detail = $"direction must be {Incoming} or {Outgoing}.";
                return false;
            }
        }

        string? type = null;
        if (query.TryGetValue("type", out var typeValues))
        {
            type = typeValues[0];
            if (type is not (Ledger.LedgerTransaction.DevelopmentFundingOperation or
                Ledger.LedgerTransaction.InternalTransferOperation))
            {
                detail = "type must be DEVELOPMENT_FUNDING or INTERNAL_TRANSFER.";
                return false;
            }
        }

        ActivityCursor? cursor = null;
        if (query.TryGetValue("cursor", out var cursorValues) &&
            !ActivityCursorCodec.TryDecode(cursorValues[0], out cursor))
        {
            detail = "cursor is invalid or expired. Refresh Activity to start again.";
            return false;
        }

        parsed = new ActivityQuery(limit, cursor, direction, type);
        return true;
    }
}

public sealed record ActivityQuery(
    int Limit,
    ActivityCursor? Cursor,
    string? Direction,
    string? Type);

public sealed record ActivityCursor(DateTime OccurredAtUtc, Guid TransactionId);

public static class ActivityCursorCodec
{
    private const byte Version = 1;
    private const int PayloadLength = 25;

    public static string Encode(ActivityCursor cursor)
    {
        Span<byte> payload = stackalloc byte[PayloadLength];
        payload[0] = Version;
        BinaryPrimitives.WriteInt64BigEndian(payload[1..9], cursor.OccurredAtUtc.ToUniversalTime().Ticks);
        cursor.TransactionId.TryWriteBytes(payload[9..]);
        return WebEncoders.Base64UrlEncode(payload);
    }

    public static bool TryDecode(string? value, out ActivityCursor? cursor)
    {
        cursor = null;
        if (string.IsNullOrEmpty(value) || value.Length > ActivityPolicy.MaximumCursorLength)
            return false;

        byte[] payload;
        try
        {
            payload = WebEncoders.Base64UrlDecode(value);
        }
        catch (FormatException)
        {
            return false;
        }

        if (payload.Length != PayloadLength || payload[0] != Version)
            return false;
        var ticks = BinaryPrimitives.ReadInt64BigEndian(payload.AsSpan(1, 8));
        if (ticks < DateTime.MinValue.Ticks || ticks > DateTime.MaxValue.Ticks)
            return false;
        var transactionId = new Guid(payload.AsSpan(9, 16));
        if (transactionId == Guid.Empty)
            return false;

        cursor = new ActivityCursor(new DateTime(ticks, DateTimeKind.Utc), transactionId);
        return string.Equals(value, Encode(cursor), StringComparison.Ordinal);
    }
}

public sealed record ActivityItemResponse(
    Guid TransactionId,
    string Type,
    string Direction,
    string Currency,
    string AmountMinor,
    string Status,
    DateTime OccurredAtUtc,
    string CounterpartyType,
    string? CounterpartyReferenceSuffix);

public sealed record ActivityPageResponse(
    IReadOnlyList<ActivityItemResponse> Items,
    string? NextCursor);

public sealed record ActivityDetailResponse(
    Guid TransactionId,
    string Type,
    string Direction,
    string Currency,
    string AmountMinor,
    string Status,
    DateTime OccurredAtUtc,
    Guid AccountReference,
    string CounterpartyType,
    Guid? CounterpartyAccountReference);

public enum ActivityLookupOutcome
{
    Found,
    AccountNotOpened,
    TransactionNotFound
}

public sealed record ActivityPageResult(bool AccountOpened, ActivityPageResponse? Page);

public sealed record ActivityDetailResult(ActivityLookupOutcome Outcome, ActivityDetailResponse? Detail = null);

public sealed class ActivityIntegrityException : Exception
{
    public ActivityIntegrityException() : base("A committed ledger journal could not be projected safely.") { }
}
