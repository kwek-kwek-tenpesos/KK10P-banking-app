using Microsoft.AspNetCore.Identity;

namespace Banking.Api.Features.Authentication;

public sealed class ApplicationUser : IdentityUser
{
    public const int MaximumEmailLength = 254;
    public const int MaximumDisplayNameLength = 60;

    public string? DisplayName { get; set; }

    // Eligibility must also be checked by the future login/session flow.
    public bool IsEnabled { get; set; } = true;
}
