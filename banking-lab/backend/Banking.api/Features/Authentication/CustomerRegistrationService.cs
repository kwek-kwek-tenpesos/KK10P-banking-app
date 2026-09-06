using banking_lab.infrastructure.temporary;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace Banking.Api.Features.Authentication;

public sealed class CustomerRegistrationService(
    UserManager<ApplicationUser> users,
    CustomerPasswordPolicy passwords,
    ICustomerVerificationDelivery verification,
    AppDbContext database,
    ILogger<CustomerRegistrationService> logger)
{
    public async Task<CustomerRegistrationResult> RegisterAsync(
        CustomerRegistrationRequest request,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(request);
        cancellationToken.ThrowIfCancellationRequested();

        var errors = new Dictionary<string, string[]>();
        var email = request.Email?.Trim();
        string? loginName;
        try
        {
            loginName = users.NormalizeEmail(email);
        }
        catch (ArgumentException)
        {
            // Malformed Unicode must produce a safe field error, not escape.
            loginName = null;
        }

        var user = new ApplicationUser
        {
            Email = email,
            UserName = loginName,
            DisplayName = request.DisplayName?.Trim(),
            EmailConfirmed = false,
            IsEnabled = true,
            LockoutEnabled = true
        };

        // This registered validator is database-free; Identity runs all its
        // validators (including uniqueness) again inside CreateAsync below.
        var inputValidator = users.UserValidators.OfType<CustomerUserValidator>().Single();
        var inputValidation = await inputValidator.ValidateAsync(users, user);
        foreach (var error in inputValidation.Errors)
        {
            var field = error.Code == "InvalidCustomerDisplayName" ? "displayName" : "email";
            errors[field] = [error.Description];
        }

        var prepared = passwords.PrepareForCreation(request.Password);
        if (!prepared.Succeeded)
        {
            errors["password"] = [prepared.Error!.Description];
        }

        if (errors.Count > 0)
        {
            return CustomerRegistrationResult.Invalid(errors);
        }

        // Do not create unusable pending users while delivery is unimplemented.
        // This check is independent of whether the submitted email exists.
        if (!verification.IsConfigured)
        {
            return CustomerRegistrationResult.Unavailable();
        }

        cancellationToken.ThrowIfCancellationRequested();
        IdentityResult creation;
        try
        {
            creation = await users.CreateAsync(user, prepared.NormalizedPassword!);
        }
        catch (DbUpdateException exception) when (IsEmailIdentityCollision(exception))
        {
            DetachFailedUser(user);
            return CustomerRegistrationResult.Accepted();
        }
        catch (Exception exception) when (
            exception is DbUpdateException or NpgsqlException or TimeoutException)
        {
            DetachFailedUser(user);
            // No exception object/message, request data or identifiers in logs.
            logger.LogWarning("Customer registration persistence failed.");
            return CustomerRegistrationResult.Unavailable();
        }

        if (!creation.Succeeded)
        {
            if (creation.Errors.Any() && creation.Errors.All(error =>
                    error.Code is "DuplicateEmail" or "DuplicateUserName"))
            {
                // Never replace a password/profile or resend mail via registration.
                return CustomerRegistrationResult.Accepted();
            }

            // Framework descriptions can include submitted identifiers.
            logger.LogWarning("Customer registration was rejected by the identity store.");
            return CustomerRegistrationResult.Unavailable();
        }

        if (!await verification.TryDeliverAsync(user.Id, cancellationToken))
        {
            // The user remains unconfirmed; the future resend flow permits retry.
            logger.LogWarning("Customer registration verification delivery failed.");
        }

        return CustomerRegistrationResult.Accepted();
    }

    private void DetachFailedUser(ApplicationUser user) =>
        database.Entry(user).State = EntityState.Detached;

    private static bool IsEmailIdentityCollision(DbUpdateException exception) =>
        exception.InnerException is PostgresException
        {
            SqlState: PostgresErrorCodes.UniqueViolation,
            TableName: "AspNetUsers",
            ConstraintName: "EmailIndex" or "UserNameIndex"
        };
}
