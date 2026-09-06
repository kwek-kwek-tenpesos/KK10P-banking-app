using System.Buffers;
using System.Net.Mail;
using System.Text;
using Microsoft.AspNetCore.Identity;

namespace Banking.Api.Features.Authentication;

// Runs alongside Identity's existing uniqueness validator. No database I/O here.
public sealed class CustomerUserValidator : IUserValidator<ApplicationUser>
{
    public Task<IdentityResult> ValidateAsync(
        UserManager<ApplicationUser> manager, ApplicationUser user)
    {
        var errors = new List<IdentityError>();
        var email = user.Email;

        // The request boundary must trim email/name before constructing the user.
        // Reject noncanonical entities here instead of silently changing identity.
        if (string.IsNullOrWhiteSpace(email)
            || email.Length > ApplicationUser.MaximumEmailLength
            || email != email.Trim()
            || email.Any(char.IsControl)
            || !MailAddress.TryCreate(email, out var address)
            || !string.Equals(address.Address, email, StringComparison.Ordinal)
            || !IsWellFormedUnicode(email))
        {
            errors.Add(new IdentityError
            {
                Code = "InvalidCustomerEmail",
                Description = "Provide a valid email address of at most 254 characters."
            });
        }
        else
        {
            var normalizedEmail = manager.NormalizeEmail(email);
            if (string.IsNullOrEmpty(normalizedEmail)
                || normalizedEmail.Length > ApplicationUser.MaximumEmailLength
                || !string.Equals(user.UserName, normalizedEmail, StringComparison.Ordinal))
            {
                errors.Add(new IdentityError
                {
                    Code = "InvalidCustomerLoginName",
                    Description = "The login name must match the normalized email."
                });
            }
        }

        if (user.DisplayName is { } displayName
            && (displayName != displayName.Trim()
                || !IsValidDisplayName(displayName)))
        {
            errors.Add(new IdentityError
            {
                Code = "InvalidCustomerDisplayName",
                Description = "Use a display name of 1 to 60 characters without control characters, or omit it."
            });
        }

        return Task.FromResult(errors.Count == 0
            ? IdentityResult.Success
            : IdentityResult.Failed(errors.ToArray()));
    }

    private static bool IsValidDisplayName(string value)
    {
        var remaining = value.AsSpan();
        var count = 0;
        while (!remaining.IsEmpty)
        {
            if (Rune.DecodeFromUtf16(remaining, out var rune, out var consumed)
                    != OperationStatus.Done
                || Rune.IsControl(rune)
                || ++count > ApplicationUser.MaximumDisplayNameLength)
            {
                return false;
            }
            remaining = remaining[consumed..];
        }
        return count > 0;
    }

    private static bool IsWellFormedUnicode(string value)
    {
        var remaining = value.AsSpan();
        while (!remaining.IsEmpty)
        {
            if (Rune.DecodeFromUtf16(remaining, out _, out var consumed)
                != OperationStatus.Done)
            {
                return false;
            }
            remaining = remaining[consumed..];
        }
        return true;
    }
}
