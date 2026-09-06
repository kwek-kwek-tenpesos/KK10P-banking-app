using System.Security.Claims;
using banking_lab.infrastructure.temporary;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace Banking.Api.Features.Authentication;

public sealed class SessionBearerEvents(AppDbContext database, UserManager<ApplicationUser> users,
    ILogger<SessionBearerEvents> logger) : JwtBearerEvents
{
    private const string DependencyFailure = "SessionDependencyFailure";

    public override async Task TokenValidated(TokenValidatedContext context)
    {
        var userId = context.Principal?.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!Guid.TryParse(context.Principal?.FindFirstValue("sid"), out var id) || string.IsNullOrEmpty(userId))
        {
            context.Fail("Invalid session.");
            return;
        }
        try
        {
            var session = await database.CustomerSessions.AsNoTracking().SingleOrDefaultAsync(s => s.Id == id,
                context.HttpContext.RequestAborted);
            var user = session is not null && session.UserId == userId ? await users.FindByIdAsync(userId) : null;
            if (session is null || !session.IsActiveAt(DateTime.UtcNow) || user is null
                || !user.IsEnabled || !user.EmailConfirmed || user.SecurityStamp != session.SecurityStamp
                || await users.IsLockedOutAsync(user))
                context.Fail("Invalid session.");
            else
                context.HttpContext.Items[typeof(ApplicationUser)] = user;
        }
        catch (Exception ex) when (AuthenticationDependencyFailure.Is(ex))
        {
            logger.LogWarning("Protected request session lookup failed.");
            context.HttpContext.Items[DependencyFailure] = true;
            context.Fail("Session unavailable.");
        }
    }

    public override async Task Challenge(JwtBearerChallengeContext context)
    {
        context.HandleResponse();
        context.Response.Headers.CacheControl = "no-store";
        var unavailable = context.HttpContext.Items.ContainsKey(DependencyFailure);
        if (!unavailable) context.Response.Headers.WWWAuthenticate = "Bearer";
        await Results.Problem(statusCode: unavailable ? 503 : 401,
            detail: unavailable ? "Authentication is temporarily unavailable." : "Authentication is required.")
            .ExecuteAsync(context.HttpContext);
    }
}
