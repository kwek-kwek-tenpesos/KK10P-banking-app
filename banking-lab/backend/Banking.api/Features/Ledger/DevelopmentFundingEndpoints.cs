using banking_lab.infrastructure.temporary;
using Banking.Api.Features.Authentication;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace Banking.Api.Features.Ledger;

public static class DevelopmentFundingEndpoints
{
    public const string RoutePrefix = "/api/v1/development/funding";
    public const string Route = RoutePrefix + "/me";

    public static void MapDevelopmentFunding(this WebApplication app)
    {
        app.MapPost(Route, ExecuteAsync)
            .RequireAuthorization()
            .RequireRateLimiting("development-funding")
            .WithName("FundCurrentDevelopmentCustomer")
            .Accepts<object>("application/json")
            .Produces<DevelopmentFundingReceipt>(201)
            .Produces<DevelopmentFundingReceipt>()
            .ProducesProblem(400).ProducesProblem(401).ProducesProblem(409)
            .ProducesProblem(413).ProducesProblem(415).ProducesProblem(429).ProducesProblem(503);
    }

    private static async Task<IResult> ExecuteAsync(
        HttpContext context,
        DevelopmentFundingService service,
        ILogger<DevelopmentFundingService> logger,
        CancellationToken cancellationToken)
    {
        if (context.Items[typeof(ApplicationUser)] is not ApplicationUser user)
            return Results.Problem(statusCode: 401, detail: "Authentication is required.");
        if (context.Items[DevelopmentFundingRequestGuards.IdempotencyItem] is not Guid idempotencyKey)
            return Results.Problem(statusCode: 400, detail: "Provide one UUID Idempotency-Key header.");

        try
        {
            var result = await service.FundAsync(user.Id, idempotencyKey, cancellationToken);
            if (result.Receipt is not null)
                logger.LogInformation("Development funding completed with outcome {Outcome} for transaction {TransactionId}.",
                    result.Outcome, result.Receipt.TransactionId);
            return result.Outcome switch
            {
                DevelopmentFundingOutcome.Created => Results.Json(result.Receipt, statusCode: 201),
                DevelopmentFundingOutcome.Replayed => Results.Ok(result.Receipt),
                DevelopmentFundingOutcome.AccountNotOpened => Conflict(
                    "Account not opened", "Open your simulator account before requesting test funds.",
                    "account_not_opened"),
                DevelopmentFundingOutcome.DailyLimitReached => Conflict(
                    "Daily funding limit reached",
                    "This simulator account has received its PHP 100,000 Development funding allowance for the Philippine calendar day.",
                    "development_funding_daily_limit_reached"),
                DevelopmentFundingOutcome.IdempotencyConflict => Conflict(
                    "Idempotency conflict", "Use a new idempotency key for a different request.",
                    "idempotency_conflict"),
                _ => Results.StatusCode(500)
            };
        }
        catch (Exception exception) when (IsUnavailable(exception))
        {
            logger.LogWarning("Development funding storage is temporarily unavailable.");
            return Results.Problem(statusCode: 503,
                detail: "Simulator funding is temporarily unavailable. Retry with the same request.");
        }
    }

    private static IResult Conflict(string title, string detail, string code) => Results.Problem(
        statusCode: 409,
        title: title,
        detail: detail,
        extensions: new Dictionary<string, object?> { ["code"] = code });

    private static bool IsUnavailable(Exception exception) => exception is TimeoutException
        or NpgsqlException { IsTransient: true }
        or PostgresException { SqlState: PostgresErrorCodes.UndefinedTable }
        || exception is DbUpdateException or InvalidOperationException
            && exception.InnerException is not null && IsUnavailable(exception.InnerException);
}
