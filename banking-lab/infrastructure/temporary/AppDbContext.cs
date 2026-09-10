using Microsoft.EntityFrameworkCore;
using Banking.Api.Features.Accounts;
using Banking.Api.Features.Authentication;
using Banking.Api.Features.Ledger;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;

namespace banking_lab.infrastructure.temporary;

public class AppDbContext : IdentityDbContext<ApplicationUser>
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
    {
    }
    public DbSet<SetupProbe> SetupProbes { get; set; }
    public DbSet<CustomerAccount> CustomerAccounts { get; set; }
    public DbSet<CustomerRefreshToken> RefreshTokens { get; set; }
    public DbSet<CustomerSession> CustomerSessions { get; set; }
    public DbSet<LedgerTransaction> LedgerTransactions { get; set; }
    public DbSet<LedgerPosting> LedgerPostings { get; set; }

    public override int SaveChanges(bool acceptAllChangesOnSuccess)
    {
        ValidateLedgerChanges();
        return base.SaveChanges(acceptAllChangesOnSuccess);
    }

    public override Task<int> SaveChangesAsync(
        bool acceptAllChangesOnSuccess,
        CancellationToken cancellationToken = default)
    {
        ValidateLedgerChanges();
        return base.SaveChangesAsync(acceptAllChangesOnSuccess, cancellationToken);
    }

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        var account = builder.Entity<CustomerAccount>();
        account.ToTable("CustomerAccounts", table =>
        {
            table.HasCheckConstraint("CK_CustomerAccounts_Currency", "\"Currency\" = 'PHP'");
            table.HasCheckConstraint("CK_CustomerAccounts_NonnegativeBalance", "\"BalanceMinor\" >= 0");
        });
        account.HasKey(a => a.Id);
        account.Property(a => a.UserId).IsRequired();
        account.Property(a => a.Currency).IsRequired().HasMaxLength(3);
        account.Property(a => a.BalanceMinor).HasDefaultValue(0L);
        account.HasIndex(a => a.UserId).IsUnique().HasDatabaseName(CustomerAccount.OwnerIndex);
        account.HasOne<ApplicationUser>().WithMany().HasForeignKey(a => a.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        var user = builder.Entity<ApplicationUser>();
        user.Property(u => u.Email)
            .IsRequired().HasMaxLength(ApplicationUser.MaximumEmailLength);
        user.Property(u => u.NormalizedEmail)
            .IsRequired().HasMaxLength(ApplicationUser.MaximumEmailLength);
        user.Property(u => u.UserName)
            .IsRequired().HasMaxLength(ApplicationUser.MaximumEmailLength);
        user.Property(u => u.NormalizedUserName)
            .IsRequired().HasMaxLength(ApplicationUser.MaximumEmailLength);
        user.HasIndex(u => u.NormalizedEmail).IsUnique();
        user.Property(u => u.DisplayName)
            .HasMaxLength(ApplicationUser.MaximumDisplayNameLength);
        user.ToTable("AspNetUsers", table => table.HasCheckConstraint(
            "CK_AspNetUsers_NormalizedLogin",
            "\"NormalizedUserName\" = \"NormalizedEmail\""));

        var token = builder.Entity<CustomerRefreshToken>();
        token.ToTable("CustomerRefreshTokens");
        token.HasKey(t => t.Id);
        token.Property(t => t.UserId).IsRequired();
        token.Property(t => t.TokenHash).IsRequired().HasMaxLength(128);
        token.HasIndex(t => t.TokenHash).IsUnique();
        token.HasIndex(t => t.UserId);
        token.HasOne<CustomerSession>().WithMany().HasForeignKey(t => t.SessionId)
            .OnDelete(DeleteBehavior.Restrict);
        token.HasOne<ApplicationUser>()
            .WithMany()
            .HasForeignKey(t => t.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        var session = builder.Entity<CustomerSession>();
        session.ToTable("CustomerSessions");
        session.HasKey(s => s.Id);
        session.Property(s => s.UserId).IsRequired();
        session.Property(s => s.Version).IsConcurrencyToken();
        session.HasIndex(s => s.UserId);
        session.HasOne<ApplicationUser>().WithMany().HasForeignKey(s => s.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        var ledgerTransaction = builder.Entity<LedgerTransaction>();
        ledgerTransaction.ToTable("LedgerTransactions", table =>
        {
            table.HasCheckConstraint("CK_LedgerTransactions_Operation",
                $"\"Operation\" IN ('{LedgerTransaction.DevelopmentFundingOperation}', " +
                $"'{LedgerTransaction.InternalTransferOperation}')");
            table.HasCheckConstraint("CK_LedgerTransactions_Currency", "\"Currency\" = 'PHP'");
            table.HasCheckConstraint("CK_LedgerTransactions_NonnegativeBalance", "\"BalanceAfterMinor\" >= 0");
            table.HasCheckConstraint("CK_LedgerTransactions_FingerprintLength",
                "char_length(\"RequestFingerprint\") = 64");
        });
        ledgerTransaction.HasKey(item => item.Id);
        ledgerTransaction.Property(item => item.Operation).IsRequired().HasMaxLength(64);
        ledgerTransaction.Property(item => item.InitiatedByUserId).IsRequired();
        ledgerTransaction.Property(item => item.RequestFingerprint).IsRequired().HasMaxLength(64);
        ledgerTransaction.Property(item => item.Currency).IsRequired().HasMaxLength(3);
        ledgerTransaction.HasIndex(item => new { item.InitiatedByUserId, item.IdempotencyKey })
            .IsUnique().HasDatabaseName(LedgerTransaction.InitiatorIdempotencyIndex);
        ledgerTransaction.HasIndex(item => item.CreatedAtUtc);
        ledgerTransaction.HasOne(item => item.InitiatedByUser).WithMany()
            .HasForeignKey(item => item.InitiatedByUserId).OnDelete(DeleteBehavior.Restrict);

        var posting = builder.Entity<LedgerPosting>();
        posting.ToTable("LedgerPostings", table =>
        {
            table.HasCheckConstraint("CK_LedgerPostings_Currency", "\"Currency\" = 'PHP'");
            table.HasCheckConstraint("CK_LedgerPostings_NonzeroAmount", "\"AmountMinor\" <> 0");
            table.HasCheckConstraint("CK_LedgerPostings_Position", "\"Position\" IN (1, 2)");
            table.HasCheckConstraint("CK_LedgerPostings_ExactlyOneAccount",
                "(\"CustomerAccountId\" IS NOT NULL)::int + (\"BookAccount\" IS NOT NULL)::int = 1");
            table.HasCheckConstraint("CK_LedgerPostings_BookAccount",
                $"\"BookAccount\" IS NULL OR \"BookAccount\" = '{LedgerPosting.SimulatorIssuer}'");
        });
        posting.HasKey(item => item.Id);
        posting.Property(item => item.BookAccount).HasMaxLength(64);
        posting.Property(item => item.Currency).IsRequired().HasMaxLength(3);
        posting.HasIndex(item => new { item.LedgerTransactionId, item.Position })
            .IsUnique().HasDatabaseName(LedgerPosting.TransactionPositionIndex);
        posting.HasIndex(item => item.CustomerAccountId);
        posting.HasIndex(item => new
            {
                item.CustomerAccountId,
                item.CreatedAtUtc,
                item.LedgerTransactionId
            })
            .IsDescending(false, true, true)
            .HasDatabaseName(LedgerPosting.ActivityHistoryIndex);
        posting.HasOne(item => item.LedgerTransaction).WithMany(item => item.Postings)
            .HasForeignKey(item => item.LedgerTransactionId).OnDelete(DeleteBehavior.Restrict);
        posting.HasOne(item => item.CustomerAccount).WithMany()
            .HasForeignKey(item => item.CustomerAccountId).OnDelete(DeleteBehavior.Restrict);
    }

    private void ValidateLedgerChanges()
    {
        if (ChangeTracker.Entries<LedgerTransaction>().Any(entry =>
                entry.State is EntityState.Modified or EntityState.Deleted) ||
            ChangeTracker.Entries<LedgerPosting>().Any(entry =>
                entry.State is EntityState.Modified or EntityState.Deleted))
            throw new InvalidOperationException("Committed ledger records are append-only.");

        foreach (var entry in ChangeTracker.Entries<LedgerTransaction>()
                     .Where(entry => entry.State == EntityState.Added))
        {
            var transaction = entry.Entity;
            var postings = transaction.Postings.ToArray();
            if (postings.Length != 2 ||
                postings.Select(posting => posting.Position).Order().SequenceEqual([(short)1, (short)2]) is false ||
                postings.Sum(posting => posting.AmountMinor) != 0 ||
                postings.Any(posting => posting.Currency != transaction.Currency ||
                    posting.CreatedAtUtc != transaction.CreatedAtUtc))
                throw new InvalidOperationException(
                    "A ledger transaction must contain one balanced, same-currency posting pair.");
        }

        if (ChangeTracker.Entries<LedgerPosting>().Any(entry =>
                entry.State == EntityState.Added &&
                (entry.Entity.LedgerTransaction is null ||
                 Entry(entry.Entity.LedgerTransaction).State != EntityState.Added)))
            throw new InvalidOperationException("Ledger postings can only be appended with their transaction.");
    }
}

public class SetupProbe
{
    public int Id { get; set; }
    public string Status { get; set; } = "Connection Verified";
    public DateTime CheckedAt { get; set; } = DateTime.UtcNow;
}
