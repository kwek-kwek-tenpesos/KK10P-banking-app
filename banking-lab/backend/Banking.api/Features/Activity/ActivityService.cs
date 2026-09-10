using System.Globalization;
using banking_lab.infrastructure.temporary;
using Banking.Api.Features.Ledger;
using Microsoft.EntityFrameworkCore;

namespace Banking.Api.Features.Activity;

public sealed class ActivityService(AppDbContext database)
{
    public async Task<ActivityPageResult> ReadPageAsync(
        string userId,
        ActivityQuery request,
        CancellationToken cancellationToken)
    {
        var accountId = await FindAccountIdAsync(userId, cancellationToken);
        if (accountId == Guid.Empty)
            return new ActivityPageResult(false, null);

        var query = database.LedgerPostings
            .AsNoTrackingWithIdentityResolution()
            .Where(posting => posting.CustomerAccountId == accountId);

        if (request.Direction == ActivityPolicy.Incoming)
            query = query.Where(posting => posting.AmountMinor > 0);
        else if (request.Direction == ActivityPolicy.Outgoing)
            query = query.Where(posting => posting.AmountMinor < 0);

        if (request.Type is not null)
            query = query.Where(posting => posting.LedgerTransaction!.Operation == request.Type);

        if (request.Cursor is not null)
        {
            var occurredAt = request.Cursor.OccurredAtUtc;
            var transactionId = request.Cursor.TransactionId;
            query = query.Where(posting =>
                posting.CreatedAtUtc < occurredAt ||
                posting.CreatedAtUtc == occurredAt && posting.LedgerTransactionId.CompareTo(transactionId) < 0);
        }

        var rows = await query
            .Include(posting => posting.LedgerTransaction)!
            .ThenInclude(transaction => transaction!.Postings)
            .OrderByDescending(posting => posting.CreatedAtUtc)
            .ThenByDescending(posting => posting.LedgerTransactionId)
            .Take(request.Limit + 1)
            .ToListAsync(cancellationToken);

        var hasMore = rows.Count > request.Limit;
        if (hasMore) rows.RemoveAt(rows.Count - 1);
        var items = rows.Select(posting => Project(posting, accountId).Item).ToArray();
        var nextCursor = hasMore && rows.Count != 0
            ? ActivityCursorCodec.Encode(new(rows[^1].CreatedAtUtc, rows[^1].LedgerTransactionId))
            : null;
        return new ActivityPageResult(true, new ActivityPageResponse(items, nextCursor));
    }

    public async Task<ActivityDetailResult> ReadDetailAsync(
        string userId,
        Guid transactionId,
        CancellationToken cancellationToken)
    {
        var accountId = await FindAccountIdAsync(userId, cancellationToken);
        if (accountId == Guid.Empty)
            return new ActivityDetailResult(ActivityLookupOutcome.AccountNotOpened);

        var posting = await database.LedgerPostings
            .AsNoTrackingWithIdentityResolution()
            .Where(item => item.CustomerAccountId == accountId &&
                item.LedgerTransactionId == transactionId)
            .Include(item => item.LedgerTransaction)!
            .ThenInclude(transaction => transaction!.Postings)
            .SingleOrDefaultAsync(cancellationToken);
        if (posting is null)
            return new ActivityDetailResult(ActivityLookupOutcome.TransactionNotFound);

        var projection = Project(posting, accountId);
        return new ActivityDetailResult(ActivityLookupOutcome.Found, new ActivityDetailResponse(
            projection.Item.TransactionId,
            projection.Item.Type,
            projection.Item.Direction,
            projection.Item.Currency,
            projection.Item.AmountMinor,
            projection.Item.Status,
            projection.Item.OccurredAtUtc,
            accountId,
            projection.Item.CounterpartyType,
            projection.CounterpartyAccountReference));
    }

    private Task<Guid> FindAccountIdAsync(string userId, CancellationToken cancellationToken) =>
        database.CustomerAccounts.AsNoTracking()
            .Where(account => account.UserId == userId)
            .Select(account => account.Id)
            .SingleOrDefaultAsync(cancellationToken);

    private static Projection Project(LedgerPosting viewerPosting, Guid accountId)
    {
        var transaction = viewerPosting.LedgerTransaction ?? throw new ActivityIntegrityException();
        var postings = transaction.Postings.OrderBy(item => item.Position).ToArray();
        if (postings.Length != 2 ||
            postings[0].Position != 1 || postings[1].Position != 2 ||
            postings.Any(item => item.Currency != transaction.Currency ||
                item.CreatedAtUtc != transaction.CreatedAtUtc) ||
            viewerPosting.Currency != transaction.Currency ||
            viewerPosting.CreatedAtUtc != transaction.CreatedAtUtc ||
            viewerPosting.AmountMinor == 0 || viewerPosting.AmountMinor == long.MinValue)
            throw new ActivityIntegrityException();

        long sum;
        try
        {
            sum = checked(postings[0].AmountMinor + postings[1].AmountMinor);
        }
        catch (OverflowException)
        {
            throw new ActivityIntegrityException();
        }
        if (sum != 0 || transaction.Currency != "PHP")
            throw new ActivityIntegrityException();

        string counterpartyType;
        Guid? counterpartyAccountReference;
        if (transaction.Operation == LedgerTransaction.DevelopmentFundingOperation)
        {
            var customers = postings.Where(item => item.CustomerAccountId == accountId).ToArray();
            var issuers = postings.Where(item => item.BookAccount == LedgerPosting.SimulatorIssuer).ToArray();
            if (customers.Length != 1 || issuers.Length != 1 ||
                customers[0].Id != viewerPosting.Id || customers[0].AmountMinor <= 0 ||
                issuers[0].AmountMinor >= 0 ||
                postings.Count(item => item.CustomerAccountId.HasValue) != 1 ||
                postings.Count(item => item.BookAccount is not null) != 1)
                throw new ActivityIntegrityException();
            counterpartyType = ActivityPolicy.SimulatorIssuer;
            counterpartyAccountReference = null;
        }
        else if (transaction.Operation == LedgerTransaction.InternalTransferOperation)
        {
            if (postings.Any(item => !item.CustomerAccountId.HasValue || item.BookAccount is not null) ||
                postings.Count(item => item.AmountMinor < 0) != 1 ||
                postings.Count(item => item.AmountMinor > 0) != 1 ||
                postings.Count(item => item.CustomerAccountId == accountId) != 1)
                throw new ActivityIntegrityException();
            counterpartyType = ActivityPolicy.Kk10pAccount;
            counterpartyAccountReference = postings.Single(item => item.CustomerAccountId != accountId)
                .CustomerAccountId;
        }
        else
        {
            throw new ActivityIntegrityException();
        }

        var amount = Math.Abs(viewerPosting.AmountMinor).ToString(CultureInfo.InvariantCulture);
        var direction = viewerPosting.AmountMinor > 0 ? ActivityPolicy.Incoming : ActivityPolicy.Outgoing;
        var suffix = counterpartyAccountReference?.ToString("N")[^8..];
        var item = new ActivityItemResponse(
            transaction.Id,
            transaction.Operation,
            direction,
            transaction.Currency,
            amount,
            ActivityPolicy.Completed,
            transaction.CreatedAtUtc,
            counterpartyType,
            suffix);
        return new Projection(item, counterpartyAccountReference);
    }

    private sealed record Projection(ActivityItemResponse Item, Guid? CounterpartyAccountReference);
}
