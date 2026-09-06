using Banking.Api.Features.Authentication;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace Banking.Api.Features.Accounts;

public static class CustomerAccountEndpoints
{
    public const string Route = "/api/v1/accounts/me";

    public static void MapCustomerAccounts(this WebApplication app)
    {
        app.MapGet(Route, (HttpContext context, CustomerAccountService service,
            ILogger<CustomerAccountService> logger, CancellationToken cancellationToken) =>
            ExecuteAsync(context, service, logger, false, cancellationToken))
            .RequireAuthorization().RequireRateLimiting("accounts").WithName("ReadCustomerAccount")
            .Produces<AccountSummary>().ProducesProblem(404).ProducesProblem(400)
            .ProducesProblem(401).ProducesProblem(413).ProducesProblem(429).ProducesProblem(503);

        app.MapPut(Route, (HttpContext context, CustomerAccountService service,
            ILogger<CustomerAccountService> logger, CancellationToken cancellationToken) =>
            ExecuteAsync(context, service, logger, true, cancellationToken))
            .RequireAuthorization().RequireRateLimiting("accounts").WithName("OpenCustomerAccount")
            .Accepts<OpenCustomerAccountRequest>("application/json")
            .Produces<AccountSummary>(201).Produces<AccountSummary>()
            .ProducesProblem(400).ProducesProblem(401).ProducesProblem(413)
            .ProducesProblem(415).ProducesProblem(429).ProducesProblem(503);
    }

    private static async Task<IResult> ExecuteAsync(HttpContext context, CustomerAccountService service,
        ILogger logger, bool open, CancellationToken cancellationToken)
    {
        if (context.Items[typeof(ApplicationUser)] is not ApplicationUser user)
            return Results.Problem(statusCode: 401, detail: "Authentication is required.");
        try
        {
            if (open)
            {
                var result = await service.OpenAsync(user.Id, cancellationToken);
                return result.Created ? Results.Created(Route, result.Account) : Results.Ok(result.Account);
            }
            var account = await service.ReadAsync(user.Id, cancellationToken);
            return account is null
                ? Results.Problem(statusCode: 404, title: "Account not opened",
                    detail: "Open your simulator account to get started.",
                    extensions: new Dictionary<string, object?> { ["code"] = "account_not_opened" })
                : Results.Ok(account);
        }
        catch (Exception exception) when (IsUnavailable(exception))
        {
            logger.LogWarning("Customer account storage is temporarily unavailable.");
            return Results.Problem(statusCode: 503, detail: "Accounts are temporarily unavailable. Please retry.");
        }
    }

    private static bool IsUnavailable(Exception exception) => exception is TimeoutException
        or NpgsqlException { IsTransient: true }
        or PostgresException { SqlState: PostgresErrorCodes.UndefinedTable }
        || exception is DbUpdateException or InvalidOperationException
            && exception.InnerException is not null && IsUnavailable(exception.InnerException);
}
