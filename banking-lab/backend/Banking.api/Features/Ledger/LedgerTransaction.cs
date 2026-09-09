using Banking.Api.Features.Authentication;

namespace Banking.Api.Features.Ledger;

public sealed class LedgerTransaction
{
    public const string DevelopmentFundingOperation = "DEVELOPMENT_FUNDING";
    public const string InternalTransferOperation = "INTERNAL_TRANSFER";
    public const string InitiatorIdempotencyIndex = "IX_LedgerTransactions_InitiatedByUserId_IdempotencyKey";

    public Guid Id { get; set; } = Guid.NewGuid();
    public required string Operation { get; set; }
    public required string InitiatedByUserId { get; set; }
    public Guid IdempotencyKey { get; set; }
    public required string RequestFingerprint { get; set; }
    public string Currency { get; set; } = "PHP";
    public long BalanceAfterMinor { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public ApplicationUser? InitiatedByUser { get; set; }
    public ICollection<LedgerPosting> Postings { get; set; } = [];
}
