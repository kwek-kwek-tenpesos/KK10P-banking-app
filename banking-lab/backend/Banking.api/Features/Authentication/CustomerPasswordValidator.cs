using Microsoft.AspNetCore.Identity;

namespace Banking.Api.Features.Authentication;

// Guards direct UserManager calls. HTTP registration/login must first call
// the appropriate CustomerPasswordPolicy preparation method and pass its
// normalized value to Identity.
public sealed class CustomerPasswordValidator(CustomerPasswordPolicy policy)
    : IPasswordValidator<ApplicationUser>
{
    public Task<IdentityResult> ValidateAsync(
        UserManager<ApplicationUser> manager,
        ApplicationUser user,
        string? password)
    {
        var prepared = policy.PrepareForCreation(password);
        if (!prepared.Succeeded)
        {
            return Task.FromResult(IdentityResult.Failed(prepared.Error!));
        }

        if (!string.Equals(
                password,
                prepared.NormalizedPassword,
                StringComparison.Ordinal))
        {
            return Task.FromResult(IdentityResult.Failed(new IdentityError
            {
                Code = "PasswordRequiresPreparation",
                Description = "Process the password through the configured policy before hashing."
            }));
        }

        return Task.FromResult(IdentityResult.Success);
    }
}
