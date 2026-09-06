using System.Globalization;
using System.Text.Json.Serialization;

namespace Banking.Api.Features.Accounts;

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record OpenCustomerAccountRequest;

public sealed record AccountSummary(Guid Id, string Currency, string BalanceMinor, DateTime OpenedAtUtc)
{
    public static AccountSummary From(CustomerAccount account) => new(account.Id, account.Currency,
        account.BalanceMinor.ToString(CultureInfo.InvariantCulture), account.OpenedAtUtc);
}

public sealed record AccountOpening(AccountSummary Account, bool Created);
