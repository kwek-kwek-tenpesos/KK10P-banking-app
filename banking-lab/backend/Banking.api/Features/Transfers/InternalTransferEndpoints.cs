using System.Diagnostics;
using banking_lab.infrastructure.temporary;
using Banking.Api.Features.Authentication;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace Banking.Api.Features.Transfers;

public sealed class InternalTransferLog;

public static class InternalTransferEndpoints
{
    public const string RoutePrefix = "/api/v1/transfers";
    public const string Route = RoutePrefix + "/internal";

    public static void MapInternalTransfers(this WebApplication app)
    {
        app.MapPost(Route, ExecuteAsync)
            .RequireAuthorization()
            .RequireRateLimiting("internal-transfer")
            .WithName("CreateInternalTransfer")
            .Accepts<InternalTransferRequest>("application/json")
            .Produces<InternalTransferReceipt>(201)
            .Produces<InternalTransferReceipt>()
            .ProducesProblem(400).ProducesProblem(401).ProducesProblem(404).ProducesProblem(409)
            .ProducesProblem(413).ProducesProblem(415).ProducesProblem(429).ProducesProblem(500)
            .ProducesProblem(503);
    }

    private static async Task<IResult> ExecuteAsync(
        HttpContext context,
        InternalTransferService service,
        ILogger<InternalTransferLog> logger,
        CancellationToken cancellationToken)
    {
        var started = Stopwatch.GetTimestamp();
        if (context.Items[typeof(ApplicationUser)] is not ApplicationUser user)
            return Results.Problem(statusCode: 401, detail: "Authentication is required.");
        if (context.Items[InternalTransferRequestGuards.IdempotencyItem] is not Guid idempotencyKey ||
            context.Items[InternalTransferRequestGuards.RequestItem] is not ValidatedInternalTransfer request)
            return Results.Problem(statusCode: 400, detail: "Provide one valid internal transfer request.");

        try
        {
            var result = await service.TransferAsync(user.Id, request.DestinationAccountReference,
                request.AmountMinor, idempotencyKey, cancellationToken);
            LogOutcome(logger, result.Outcome.ToString(), result.Receipt?.TransactionId, started);
            return result.Outcome switch
            {
                InternalTransferOutcome.Created => Results.Json(result.Receipt, statusCode: 201),
                InternalTransferOutcome.Replayed => Results.Ok(result.Receipt),
                InternalTransferOutcome.AccountNotOpened => Problem(409, "Account not opened",
                    "Open your simulator account before transferring funds.", "account_not_opened"),
                InternalTransferOutcome.RecipientNotFound => Problem(404, "Recipient not found",
                    "The supplied simulator account cannot receive this transfer.", "recipient_not_found"),
                InternalTransferOutcome.SelfTransferNotAllowed => Problem(409, "Self-transfer not allowed",
                    "Choose another simulator account.", "self_transfer_not_allowed"),
                InternalTransferOutcome.IdempotencyConflict => Problem(409, "Idempotency conflict",
                    "Use a new idempotency key for a different request.", "idempotency_conflict"),
                InternalTransferOutcome.InsufficientFunds => Problem(409, "Insufficient funds",
                    "The simulator account does not have enough funds.", "insufficient_funds"),
                InternalTransferOutcome.OutgoingDailyLimitReached => Problem(409, "Daily limit reached",
                    "This transfer would exceed the PHP 100,000 daily outgoing limit.",
                    "outgoing_daily_limit_reached"),
                _ => Results.StatusCode(500)
            };
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception) when (IsUnavailable(exception))
        {
            logger.LogWarning("Internal transfer ended with outcome {Outcome} in {DurationMs} ms.",
                "storage_unavailable", Stopwatch.GetElapsedTime(started).TotalMilliseconds);
            return Results.Problem(statusCode: 503,
                detail: "Internal transfers are temporarily unavailable. Retry the same request with the same key.");
        }
        catch (Exception exception)
        {
            logger.LogError(
                "Internal transfer ended with outcome {Outcome}, exception type {ExceptionType}, in {DurationMs} ms.",
                "unexpected_failure", exception.GetType().Name,
                Stopwatch.GetElapsedTime(started).TotalMilliseconds);
            return Results.Problem(statusCode: 500,
                detail: "The internal transfer could not be completed.");
        }
    }

    private static void LogOutcome(ILogger logger, string outcome, Guid? transactionId, long started)
    {
        if (transactionId.HasValue)
            logger.LogInformation(
                "Internal transfer ended with outcome {Outcome}, transaction {TransactionId}, in {DurationMs} ms.",
                outcome, transactionId, Stopwatch.GetElapsedTime(started).TotalMilliseconds);
        else
            logger.LogInformation("Internal transfer ended with outcome {Outcome} in {DurationMs} ms.",
                outcome, Stopwatch.GetElapsedTime(started).TotalMilliseconds);
    }

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
