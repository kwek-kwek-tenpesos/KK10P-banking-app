using banking_lab.infrastructure.temporary;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace Banking.Api.Features.Accounts;

public sealed class CustomerAccountService(AppDbContext database)
{
    public async Task<AccountSummary?> ReadAsync(string userId, CancellationToken cancellationToken)
    {
        var account = await database.CustomerAccounts.AsNoTracking()
            .SingleOrDefaultAsync(a => a.UserId == userId, cancellationToken);
        return account is null ? null : AccountSummary.From(account);
    }

    public async Task<AccountOpening> OpenAsync(string userId, CancellationToken cancellationToken)
    {
        var existing = await ReadAsync(userId, cancellationToken);
        if (existing is not null) return new(existing, false);

        var account = new CustomerAccount { UserId = userId };
        database.CustomerAccounts.Add(account);
        try
        {
            await database.SaveChangesAsync(cancellationToken);
            // Return persisted timestamp precision so creation and retries agree.
            var persisted = await ReadAsync(userId, cancellationToken)
                ?? throw new InvalidOperationException("Committed account could not be read.");
            return new(persisted, true);
        }
        catch (DbUpdateException exception) when (exception.InnerException is PostgresException
            { SqlState: PostgresErrorCodes.UniqueViolation, ConstraintName: CustomerAccount.OwnerIndex })
        {
            // SaveChanges owns its transaction. A concurrent winner must be read
            // afresh after rollback; never retry inserting or reset its values.
            database.Entry(account).State = EntityState.Detached;
            var winner = await ReadAsync(userId, cancellationToken);
            if (winner is null) throw;
            return new(winner, false);
        }
    }
}
