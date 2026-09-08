using System.Data;
using banking_lab.infrastructure.temporary;
using Banking.Api.Features.Accounts;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace Banking.Api.Features.Ledger;

public sealed class DevelopmentFundingService(AppDbContext database, TimeProvider timeProvider)
{
    public async Task<DevelopmentFundingResult> FundAsync(
        string userId,
        Guid idempotencyKey,
        CancellationToken cancellationToken)
    {
        await using var transaction = await BeginTransactionAsync(cancellationToken);
        var account = await LockAccountAsync(userId, cancellationToken);
        if (account is null)
        {
            await CommitAsync(transaction, cancellationToken);
            return new(DevelopmentFundingOutcome.AccountNotOpened);
        }

        var existing = await database.LedgerTransactions
            .Include(item => item.Postings)
            .SingleOrDefaultAsync(item => item.InitiatedByUserId == userId &&
                item.IdempotencyKey == idempotencyKey, cancellationToken);
        if (existing is not null)
        {
            if (existing.Operation != LedgerTransaction.DevelopmentFundingOperation ||
                existing.RequestFingerprint != DevelopmentFundingPolicy.RequestFingerprint)
            {
                await CommitAsync(transaction, cancellationToken);
                return new(DevelopmentFundingOutcome.IdempotencyConflict);
            }

            var creditedAccountId = existing.Postings
                .Single(posting => posting.CustomerAccountId.HasValue && posting.AmountMinor > 0)
                .CustomerAccountId!.Value;
            await CommitAsync(transaction, cancellationToken);
            return new(DevelopmentFundingOutcome.Replayed,
                DevelopmentFundingReceipt.From(existing, creditedAccountId, true));
        }

        var now = timeProvider.GetUtcNow();
        var day = PhilippineBusinessDay.For(now);
        var issuedToday = await database.LedgerPostings
            .Where(posting => posting.CustomerAccountId == account.Id && posting.AmountMinor > 0 &&
                posting.LedgerTransaction!.Operation == LedgerTransaction.DevelopmentFundingOperation &&
                posting.LedgerTransaction.CreatedAtUtc >= day.StartUtc &&
                posting.LedgerTransaction.CreatedAtUtc < day.EndUtc)
            .SumAsync(posting => (long?)posting.AmountMinor, cancellationToken) ?? 0;
        if (issuedToday > DevelopmentFundingPolicy.DailyLimitMinor - DevelopmentFundingPolicy.GrantMinor)
        {
            await CommitAsync(transaction, cancellationToken);
            return new(DevelopmentFundingOutcome.DailyLimitReached);
        }

        account.BalanceMinor = checked(account.BalanceMinor + DevelopmentFundingPolicy.GrantMinor);
        var createdAtUtc = now.UtcDateTime;
        var ledgerTransaction = new LedgerTransaction
        {
            Operation = LedgerTransaction.DevelopmentFundingOperation,
            InitiatedByUserId = userId,
            IdempotencyKey = idempotencyKey,
            RequestFingerprint = DevelopmentFundingPolicy.RequestFingerprint,
            Currency = DevelopmentFundingPolicy.Currency,
            BalanceAfterMinor = account.BalanceMinor,
            CreatedAtUtc = createdAtUtc,
            Postings =
            [
                new LedgerPosting
                {
                    Position = 1,
                    BookAccount = LedgerPosting.SimulatorIssuer,
                    AmountMinor = -DevelopmentFundingPolicy.GrantMinor,
                    Currency = DevelopmentFundingPolicy.Currency,
                    CreatedAtUtc = createdAtUtc
                },
                new LedgerPosting
                {
                    Position = 2,
                    CustomerAccountId = account.Id,
                    AmountMinor = DevelopmentFundingPolicy.GrantMinor,
                    Currency = DevelopmentFundingPolicy.Currency,
                    CreatedAtUtc = createdAtUtc
                }
            ]
        };
        database.LedgerTransactions.Add(ledgerTransaction);
        await database.SaveChangesAsync(cancellationToken);
        await CommitAsync(transaction, cancellationToken);
        return new(DevelopmentFundingOutcome.Created,
            DevelopmentFundingReceipt.From(ledgerTransaction, account.Id, false));
    }

    private async Task<CustomerAccount?> LockAccountAsync(string userId, CancellationToken cancellationToken)
    {
        if (IsPostgres())
        {
            var accountId = await database.Database.SqlQuery<Guid>(
                    $"""SELECT "Id" AS "Value" FROM "CustomerAccounts" WHERE "UserId" = {userId} FOR UPDATE""")
                .SingleOrDefaultAsync(cancellationToken);
            return accountId == Guid.Empty
                ? null
                : await database.CustomerAccounts.SingleAsync(account => account.Id == accountId, cancellationToken);
        }
        return await database.CustomerAccounts.SingleOrDefaultAsync(account => account.UserId == userId,
            cancellationToken);
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
