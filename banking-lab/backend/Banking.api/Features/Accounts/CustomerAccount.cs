namespace Banking.Api.Features.Accounts;

public sealed class CustomerAccount
{
    public const string OwnerIndex = "IX_CustomerAccounts_UserId";
    public Guid Id { get; set; } = Guid.NewGuid();
    public required string UserId { get; set; }
    public string Currency { get; set; } = "PHP";
    public long BalanceMinor { get; set; }
    public DateTime OpenedAtUtc { get; set; } = DateTime.UtcNow;
}
