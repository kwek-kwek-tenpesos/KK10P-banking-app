using System.Buffers;
using System.Text;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Identity;

namespace Banking.Api.Features.Authentication;

public interface ICustomerPasswordBlocklist
{
    bool Contains(string normalizedPassword);
}

// This small first list blocks exact common/app-specific demo choices only.
// It is deliberately replaceable and is not a comprehensive breach corpus.
public sealed class InitialCustomerPasswordBlocklist : ICustomerPasswordBlocklist
{
    private static readonly HashSet<string> BlockedPasswords = new(
        StringComparer.OrdinalIgnoreCase)
    {
        "123456789012345",
        "bankinglabpassword",
        "kk10pbankkk10pbank",
        "kk10pbankpassword",
        "password123456789",
        "passwordpassword",
        "qwertyuiopasdfgh"
    };

    public bool Contains(string normalizedPassword) =>
        BlockedPasswords.Contains(normalizedPassword);
}

public sealed class PasswordPreparationResult
{
    internal PasswordPreparationResult(string? normalizedPassword, IdentityError? error)
    {
        NormalizedPassword = normalizedPassword;
        Error = error;
    }

    // Transient credential material: never log or return this property from an API.
    [JsonIgnore]
    public string? NormalizedPassword { get; }

    public IdentityError? Error { get; }
    public bool Succeeded => Error is null;

    public override string ToString() =>
        $"PasswordPreparationResult {{ Succeeded = {Succeeded} }}";
}

public sealed class CustomerPasswordPolicy(ICustomerPasswordBlocklist blocklist)
{
    public const int MinimumLength = 15;
    public const int MaximumLength = 128;

    // Allows canonical composition to reduce a bounded decomposed input while
    // preventing an unexpectedly large value from reaching normalization.
    private const int MaximumInputCodePoints = MaximumLength * 4;

    public PasswordPreparationResult PrepareForCreation(string? password)
    {
        var prepared = PrepareForVerification(password);
        if (!prepared.Succeeded)
        {
            return prepared;
        }

        var normalizedPassword = prepared.NormalizedPassword!;
        _ = TryCountCodePoints(normalizedPassword, MaximumLength, out var length);
        if (length < MinimumLength)
        {
            return Failed(
                "PasswordTooShort",
                $"Use at least {MinimumLength} characters.");
        }

        if (blocklist.Contains(normalizedPassword))
        {
            return Failed(
                "PasswordBlocked",
                "Choose a less predictable password or passphrase.");
        }

        return prepared;
    }

    // Login must not reapply new-password rules after a policy/blocklist update.
    // It needs the same normalization and resource bounds, then Identity checks
    // the hash. This result alone never proves that a credential is correct.
    public PasswordPreparationResult PrepareForVerification(string? password)
    {
        if (password is null
            || !TryCountCodePoints(password, MaximumInputCodePoints, out var inputLength))
        {
            return Failed(
                "InvalidPassword",
                "Provide a valid Unicode password.");
        }

        if (inputLength > MaximumInputCodePoints)
        {
            return Failed(
                "PasswordTooLong",
                $"Use no more than {MaximumLength} characters.");
        }

        var normalizedPassword = password.Normalize(NormalizationForm.FormC);
        _ = TryCountCodePoints(normalizedPassword, MaximumLength, out var length);

        if (length > MaximumLength)
        {
            return Failed(
                "PasswordTooLong",
                $"Use no more than {MaximumLength} characters.");
        }

        return new PasswordPreparationResult(normalizedPassword, null);
    }

    private static PasswordPreparationResult Failed(string code, string description) =>
        new(null, new IdentityError { Code = code, Description = description });

    private static bool TryCountCodePoints(
        string value,
        int stopAfter,
        out int count)
    {
        var remaining = value.AsSpan();
        count = 0;

        while (!remaining.IsEmpty)
        {
            if (Rune.DecodeFromUtf16(remaining, out _, out var consumed)
                != OperationStatus.Done)
            {
                return false;
            }

            count++;
            if (count > stopAfter)
            {
                return true;
            }

            remaining = remaining[consumed..];
        }

        return true;
    }
}
