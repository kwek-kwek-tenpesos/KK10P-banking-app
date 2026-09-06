using Microsoft.EntityFrameworkCore;
using Banking.Api.Features.Accounts;
using Banking.Api.Features.Authentication;
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

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        var account = builder.Entity<CustomerAccount>();
        account.ToTable("CustomerAccounts", table =>
        {
            table.HasCheckConstraint("CK_CustomerAccounts_Currency", "\"Currency\" = 'PHP'");
            table.HasCheckConstraint("CK_CustomerAccounts_ZeroBalance", "\"BalanceMinor\" = 0");
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
    }
}

public class SetupProbe
{
    public int Id { get; set; }
    public string Status { get; set; } = "Connection Verified";
    public DateTime CheckedAt { get; set; } = DateTime.UtcNow;
}
