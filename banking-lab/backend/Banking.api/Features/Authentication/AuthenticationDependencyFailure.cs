using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace Banking.Api.Features.Authentication;

internal static class AuthenticationDependencyFailure
{
    // Npgsql's non-retrying execution strategy wraps transient read failures.
    // Do not swallow unrelated InvalidOperationException programming defects.
    public static bool Is(Exception exception) => exception is DbUpdateException or NpgsqlException or TimeoutException
        || exception is InvalidOperationException { InnerException: NpgsqlException or TimeoutException };
}
