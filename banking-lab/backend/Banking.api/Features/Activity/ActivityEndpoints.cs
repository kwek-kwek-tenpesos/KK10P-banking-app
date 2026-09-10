using System.Diagnostics;
using banking_lab.infrastructure.temporary;
using Banking.Api.Features.Authentication;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace Banking.Api.Features.Activity;

public sealed class ActivityLog;

public static class ActivityEndpoints
{
    public const string RoutePrefix = "/api/v1/accounts/me/transactions";

    public static void MapActivity(this WebApplication app)
    {
        app.MapGet(RoutePrefix, ReadPageAsync)
            .RequireAuthorization()
            .RequireRateLimiting(ActivityRequestGuards.RateLimitPolicy)
            .WithName("ReadCurrentAccountActivity")
            .Produces<ActivityPageResponse>()
            .ProducesProblem(400).ProducesProblem(401).ProducesProblem(404)
            .ProducesProblem(429).ProducesProblem(500).ProducesProblem(503);

        app.MapGet(RoutePrefix + "/{transactionId}", ReadDetailAsync)
            .RequireAuthorization()
            .RequireRateLimiting(ActivityRequestGuards.RateLimitPolicy)
            .WithName("ReadCurrentAccountTransaction")
            .Produces<ActivityDetailResponse>()
            .ProducesProblem(400).ProducesProblem(401).ProducesProblem(404)
            .ProducesProblem(429).ProducesProblem(500).ProducesProblem(503);
    }

    private static async Task<IResult> ReadPageAsync(
        HttpContext context,
        ActivityService service,
        ILogger<ActivityLog> logger,
        CancellationToken cancellationToken)
    {
        if (context.Items[ActivityRequestGuards.QueryItem] is not ActivityQuery query)
            return Problem(400, "Invalid Activity request", "Provide valid Activity parameters.",
                "invalid_activity_query");
        return await ExecuteAsync(context, logger, async user =>
        {
            var result = await service.ReadPageAsync(user.Id, query, cancellationToken);
            return result.AccountOpened
                ? Results.Ok(result.Page)
                : AccountNotOpened();
        });
    }

    private static async Task<IResult> ReadDetailAsync(
        string transactionId,
        HttpContext context,
        ActivityService service,
        ILogger<ActivityLog> logger,
        CancellationToken cancellationToken)
    {
        if (!Guid.TryParseExact(transactionId, "D", out var parsed) || parsed == Guid.Empty ||
            !string.Equals(transactionId, parsed.ToString("D"), StringComparison.Ordinal))
            return Problem(400, "Invalid transaction reference",
                "transactionId must be one canonical non-empty UUID.", "invalid_activity_query");

        return await ExecuteAsync(context, logger, async user =>
        {
            var result = await service.ReadDetailAsync(user.Id, parsed, cancellationToken);
            return result.Outcome switch
            {
                ActivityLookupOutcome.Found => Results.Ok(result.Detail),
                ActivityLookupOutcome.AccountNotOpened => AccountNotOpened(),
                _ => Problem(404, "Transaction not found",
                    "That transaction is not available for this simulator account.",
                    "transaction_not_found")
            };
        });
    }

    private static async Task<IResult> ExecuteAsync(
        HttpContext context,
        ILogger<ActivityLog> logger,
        Func<ApplicationUser, Task<IResult>> execute)
    {
        var started = Stopwatch.GetTimestamp();
        if (context.Items[typeof(ApplicationUser)] is not ApplicationUser user)
            return Results.Problem(statusCode: 401, detail: "Authentication is required.");
        try
        {
            var result = await execute(user);
            logger.LogInformation("Activity read completed in {DurationMs} ms.",
                Stopwatch.GetElapsedTime(started).TotalMilliseconds);
            return result;
        }
        catch (OperationCanceledException) when (context.RequestAborted.IsCancellationRequested)
        {
            throw;
        }
        catch (ActivityIntegrityException)
        {
            logger.LogError("Activity read detected an invalid committed journal in {DurationMs} ms.",
                Stopwatch.GetElapsedTime(started).TotalMilliseconds);
            return Problem(503, "Activity unavailable",
                "Activity is temporarily unavailable. Please try again later.", "activity_unavailable");
        }
        catch (Exception exception) when (IsUnavailable(exception))
        {
            logger.LogWarning("Activity storage was unavailable in {DurationMs} ms.",
                Stopwatch.GetElapsedTime(started).TotalMilliseconds);
            return Problem(503, "Activity unavailable",
                "Activity is temporarily unavailable. Please try again.", "activity_unavailable");
        }
        catch (Exception exception)
        {
            logger.LogError("Activity read failed with {ExceptionType} in {DurationMs} ms.",
                exception.GetType().Name, Stopwatch.GetElapsedTime(started).TotalMilliseconds);
            return Results.Problem(statusCode: 500, detail: "Activity could not be loaded.");
        }
    }

    private static IResult AccountNotOpened() => Problem(404, "Account not opened",
        "Open your simulator account to view Activity.", "account_not_opened");

    private static IResult Problem(int status, string title, string detail, string code) => Results.Problem(
        statusCode: status,
        title: title,
        detail: detail,
        extensions: new Dictionary<string, object?> { ["code"] = code });

    private static bool IsUnavailable(Exception exception) => exception is TimeoutException
        or NpgsqlException { IsTransient: true }
        or PostgresException { SqlState: PostgresErrorCodes.UndefinedTable }
        || exception is DbUpdateException or InvalidOperationException
            && exception.InnerException is not null && IsUnavailable(exception.InnerException);
}
