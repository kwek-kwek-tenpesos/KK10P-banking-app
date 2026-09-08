using Banking.Api.Features.Accounts;

namespace Banking.Api.Features.Ledger;

public sealed class LedgerPosting
{
    public const string SimulatorIssuer = "SIMULATOR_ISSUER";
    public const string TransactionPositionIndex = "IX_LedgerPostings_LedgerTransactionId_Position";

    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid LedgerTransactionId { get; set; }
    public short Position { get; set; }
    public Guid? CustomerAccountId { get; set; }
    public string? BookAccount { get; set; }
    public long AmountMinor { get; set; }
    public string Currency { get; set; } = "PHP";
    public DateTime CreatedAtUtc { get; set; }
    public LedgerTransaction? LedgerTransaction { get; set; }
    public CustomerAccount? CustomerAccount { get; set; }
}
