using System.Data;
using System.Globalization;
using banking_lab.infrastructure.temporary;
using Banking.Api.Features.Accounts;
using Banking.Api.Features.Ledger;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace Banking.Api.Features.Transfers;

public sealed class InternalTransferService(AppDbContext database, TimeProvider timeProvider)
{
    public async Task<InternalTransferResult> TransferAsync(
        string userId,
        Guid destinationAccountReference,
        long amountMinor,
        Guid idempotencyKey,
        CancellationToken cancellationToken)
    {
        await using var transaction = await BeginTransactionAsync(cancellationToken);
        var sourceId = await database.CustomerAccounts
            .Where(account => account.UserId == userId)
            .Select(account => account.Id)
            .SingleOrDefaultAsync(cancellationToken);
        if (sourceId == Guid.Empty)
            return await FinishAsync(transaction, new(InternalTransferOutcome.AccountNotOpened), cancellationToken);
        await LockAccountsAsync(sourceId, destinationAccountReference, cancellationToken);
        var accounts = await database.CustomerAccounts
            .Where(account => account.Id == sourceId || account.Id == destinationAccountReference)
            .ToDictionaryAsync(account => account.Id, cancellationToken);
        if (!accounts.TryGetValue(sourceId, out var source))
            return await FinishAsync(transaction, new(InternalTransferOutcome.AccountNotOpened), cancellationToken);

        var fingerprint = InternalTransferPolicy.Fingerprint(source.Id, destinationAccountReference, amountMinor);
        var existing = await database.LedgerTransactions
            .Include(item => item.Postings)
            .SingleOrDefaultAsync(item => item.InitiatedByUserId == userId &&
                item.IdempotencyKey == idempotencyKey, cancellationToken);
        if (existing is not null)
        {
            if (existing.Operation != LedgerTransaction.InternalTransferOperation ||
                existing.RequestFingerprint != fingerprint)
                return await FinishAsync(transaction,
                    new(InternalTransferOutcome.IdempotencyConflict), cancellationToken);

            return await FinishAsync(transaction,
                new(InternalTransferOutcome.Replayed,
                    ReceiptFrom(existing, source.Id, destinationAccountReference, amountMinor, true)), cancellationToken);
        }

        if (sourceId == destinationAccountReference)
            return await FinishAsync(transaction, new(InternalTransferOutcome.SelfTransferNotAllowed), cancellationToken);
        if (!accounts.TryGetValue(destinationAccountReference, out var destination))
            return await FinishAsync(transaction, new(InternalTransferOutcome.RecipientNotFound), cancellationToken);

        var now = timeProvider.GetUtcNow();
        var day = PhilippineBusinessDay.For(now);
        var sentToday = await database.LedgerPostings
            .Where(posting => posting.CustomerAccountId == source.Id && posting.AmountMinor < 0 &&
                posting.LedgerTransaction!.Operation == LedgerTransaction.InternalTransferOperation &&
                posting.LedgerTransaction.CreatedAtUtc >= day.StartUtc &&
                posting.LedgerTransaction.CreatedAtUtc < day.EndUtc)
            .SumAsync(posting => (long?)-posting.AmountMinor, cancellationToken) ?? 0;
        if (sentToday > InternalTransferPolicy.DailyOutgoingLimitMinor - amountMinor)
            return await FinishAsync(transaction,
                new(InternalTransferOutcome.OutgoingDailyLimitReached), cancellationToken);
        if (source.BalanceMinor < amountMinor)
            return await FinishAsync(transaction,
                new(InternalTransferOutcome.InsufficientFunds), cancellationToken);

        source.BalanceMinor = checked(source.BalanceMinor - amountMinor);
        destination.BalanceMinor = checked(destination.BalanceMinor + amountMinor);
        var createdAtUtc = now.UtcDateTime;
        var ledgerTransaction = new LedgerTransaction
        {
            Operation = LedgerTransaction.InternalTransferOperation,
            InitiatedByUserId = userId,
            IdempotencyKey = idempotencyKey,
            RequestFingerprint = fingerprint,
            Currency = InternalTransferPolicy.Currency,
            BalanceAfterMinor = source.BalanceMinor,
            CreatedAtUtc = createdAtUtc,
            Postings =
            [
                new LedgerPosting
                {
                    Position = 1,
                    CustomerAccountId = source.Id,
                    AmountMinor = -amountMinor,
                    Currency = InternalTransferPolicy.Currency,
                    CreatedAtUtc = createdAtUtc
                },
                new LedgerPosting
                {
                    Position = 2,
                    CustomerAccountId = destination.Id,
                    AmountMinor = amountMinor,
                    Currency = InternalTransferPolicy.Currency,
                    CreatedAtUtc = createdAtUtc
                }
            ]
        };
        database.LedgerTransactions.Add(ledgerTransaction);
        await database.SaveChangesAsync(cancellationToken);
        await CommitAsync(transaction, cancellationToken);
        return new(InternalTransferOutcome.Created,
            ReceiptFrom(ledgerTransaction, source.Id, destination.Id, amountMinor, false));
    }

    private async Task LockAccountsAsync(Guid source, Guid destination, CancellationToken cancellationToken)
    {
        if (!IsPostgres()) return;
        var first = source.CompareTo(destination) < 0 ? source : destination;
        var second = source.CompareTo(destination) < 0 ? destination : source;
        await database.Database.SqlQuery<Guid>($"""
                SELECT "Id" AS "Value"
                FROM "CustomerAccounts"
                WHERE "Id" = {first} OR "Id" = {second}
                ORDER BY "Id"
                FOR UPDATE
                """)
            .ToListAsync(cancellationToken);
    }

    private static InternalTransferReceipt ReceiptFrom(LedgerTransaction transaction,
        Guid source, Guid destination, long amount, bool replayed) => new(
        transaction.Id,
        source,
        destination,
        transaction.Currency,
        amount.ToString(CultureInfo.InvariantCulture),
        transaction.BalanceAfterMinor.ToString(CultureInfo.InvariantCulture),
        InternalTransferPolicy.CompletedStatus,
        transaction.CreatedAtUtc,
        replayed);

    private static async Task<InternalTransferResult> FinishAsync(IDbContextTransaction? transaction,
        InternalTransferResult result, CancellationToken cancellationToken)
    {
        await CommitAsync(transaction, cancellationToken);
        return result;
    }

    private Task<IDbContextTransaction?> BeginTransactionAsync(CancellationToken cancellationToken) =>
        IsPostgres()
            ? BeginRelationalTransactionAsync(cancellationToken)
            : Task.FromResult<IDbContextTransaction?>(null);

    private async Task<IDbContextTransaction?> BeginRelationalTransactionAsync(CancellationToken cancellationToken) =>
        await database.Database.BeginTransactionAsync(IsolationLevel.ReadCommitted, cancellationToken);

    private static Task CommitAsync(IDbContextTransaction? transaction, CancellationToken cancellationToken) =>
        transaction is null ? Task.CompletedTask : transaction.CommitAsync(cancellationToken);

    private bool IsPostgres() => string.Equals(database.Database.ProviderName,
        "Npgsql.EntityFrameworkCore.PostgreSQL", StringComparison.Ordinal);
}
