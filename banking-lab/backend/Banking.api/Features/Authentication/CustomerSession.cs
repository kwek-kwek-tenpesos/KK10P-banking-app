namespace Banking.Api.Features.Authentication;

public sealed class CustomerSession
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string UserId { get; set; } = string.Empty;
    public string? SecurityStamp { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime LastActivityAtUtc { get; set; }
    public DateTime IdleExpiresAtUtc { get; set; }
    public DateTime AbsoluteExpiresAtUtc { get; set; }
    public DateTime? RevokedAtUtc { get; set; }
    public Guid Version { get; set; } = Guid.NewGuid();
    public DateTime RefreshWindowStartedAtUtc { get; set; }
    public int RefreshWindowCount { get; set; }

    public bool IsActiveAt(DateTime now) => RevokedAtUtc is null
        && now < IdleExpiresAtUtc && now < AbsoluteExpiresAtUtc;

    public DateTime AccessDeadline => IdleExpiresAtUtc < AbsoluteExpiresAtUtc
        ? IdleExpiresAtUtc : AbsoluteExpiresAtUtc;
}
