using banking_lab.infrastructure.temporary;
using Banking.Api.Features.Authentication;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Logging;

namespace Banking.IntegrationTests;

// Test-only replacement for persistence/delivery. Real UserManager, validators,
// normalizer and hasher still run. This does not simulate PostgreSQL constraints.
internal sealed class RegistrationTestHost : WebApplicationFactory<Program>
{
    private readonly string environment;
    public RegistrationTestHost(string environment = "Testing")
    {
        this.environment = environment;
        ClientOptions.BaseAddress = new Uri("https://localhost");
    }
    public bool FailDatabaseWrites { get; set; }
    public RegistrationTestStore Store { get; } = new();
    public RecordingVerificationDelivery Delivery { get; } = new();
    public RegistrationTestLogger Log { get; } = new();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment(environment);
        builder.UseTestAuthentication();
        builder.ConfigureAppConfiguration((_, configuration) =>
            configuration.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:DefaultConnection"] = null,
                ["Jwt:SigningKey"] = "test-only-hmac-sha256-signing-key-banking-lab-at-least-32-chars-long!",
                ["Jwt:Issuer"] = "BankingLabTest",
                ["Jwt:Audience"] = "BankingTestAudience"
            }));
        builder.ConfigureServices(services =>
        {
            var internalProvider = new ServiceCollection()
                .AddEntityFrameworkInMemoryDatabase()
                .BuildServiceProvider();

            services.RemoveAll<AppDbContext>();
            services.RemoveAll<DbContextOptions<AppDbContext>>();
            services.AddDbContext<AppDbContext>(options =>
            {
                options.UseInMemoryDatabase("BankingTestDb");
                options.UseInternalServiceProvider(internalProvider);
                options.AddInterceptors(new WriteFailureInterceptor(() => FailDatabaseWrites));
            });

            services.RemoveAll<IUserStore<ApplicationUser>>();
            services.AddScoped<IUserStore<ApplicationUser>>(_ => Store);
            services.RemoveAll<ICustomerVerificationDelivery>();
            services.AddSingleton<ICustomerVerificationDelivery>(Delivery);
            services.AddSingleton<ILogger<CustomerRegistrationService>>(Log);
        });
    }

    private sealed class WriteFailureInterceptor(Func<bool> shouldFail) : SaveChangesInterceptor
    {
        public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
            DbContextEventData eventData, InterceptionResult<int> result,
            CancellationToken cancellationToken = default)
        {
            if (shouldFail()) throw new TimeoutException("Injected test persistence failure.");
            return ValueTask.FromResult(result);
        }
    }
}

internal sealed class RecordingVerificationDelivery : ICustomerVerificationDelivery
{
    public bool IsConfigured { get; set; } = true;
    public bool Succeeds { get; set; } = true;
    public List<string> RequestedUserIds { get; } = [];

    public Task<bool> TryDeliverAsync(string userId, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        RequestedUserIds.Add(userId);
        return Task.FromResult(Succeeds);
    }
}

internal sealed class RegistrationTestLogger : ILogger<CustomerRegistrationService>
{
    public List<string> Messages { get; } = [];
    public List<Exception> Exceptions { get; } = [];
    public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;
    public bool IsEnabled(LogLevel logLevel) => true;
    public void Log<TState>(LogLevel logLevel, EventId eventId, TState state,
        Exception? exception, Func<TState, Exception?, string> formatter)
    {
        Messages.Add(formatter(state, exception));
        if (exception is not null)
        {
            Exceptions.Add(exception);
        }
    }
}

internal sealed class RegistrationTestStore :
    IUserPasswordStore<ApplicationUser>, IUserEmailStore<ApplicationUser>,
    IUserSecurityStampStore<ApplicationUser>, IUserLockoutStore<ApplicationUser>
{
    public List<ApplicationUser> Users { get; } = [];
    public int Reads { get; private set; }
    public int CreateCalls { get; private set; }
    public Action<ApplicationUser>? BeforeCreate { get; set; }
    public Exception? CreateFailure { get; set; }
    public Exception? LookupFailure { get; set; }
    public IdentityResult CreateResult { get; set; } = IdentityResult.Success;
    public IdentityResult UpdateResult { get; set; } = IdentityResult.Success;

    public Task<IdentityResult> CreateAsync(ApplicationUser user, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        CreateCalls++;
        BeforeCreate?.Invoke(user);
        if (CreateFailure is not null)
        {
            throw CreateFailure;
        }
        if (CreateResult.Succeeded)
        {
            Users.Add(user);
        }
        return Task.FromResult(CreateResult);
    }

    public Task<IdentityResult> UpdateAsync(ApplicationUser user, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (!UpdateResult.Succeeded) return Task.FromResult(UpdateResult);
        var index = Users.FindIndex(u => u.Id == user.Id);
        if (index >= 0)
        {
            Users[index] = user;
        }
        else
        {
            Users.Add(user);
        }
        return Task.FromResult(IdentityResult.Success);
    }

    public Task<IdentityResult> DeleteAsync(ApplicationUser user, CancellationToken cancellationToken) =>
        throw new NotSupportedException("Registration must not delete a test user.");

    public Task<ApplicationUser?> FindByIdAsync(string userId, CancellationToken cancellationToken)
    {
        Reads++;
        return Task.FromResult(Users.SingleOrDefault(user => user.Id == userId));
    }
    public Task<ApplicationUser?> FindByNameAsync(string normalizedUserName, CancellationToken cancellationToken)
    {
        Reads++;
        if (LookupFailure is not null)
        {
            throw LookupFailure;
        }
        return Task.FromResult(Users.SingleOrDefault(user => user.NormalizedUserName == normalizedUserName));
    }
    public Task<ApplicationUser?> FindByEmailAsync(string normalizedEmail, CancellationToken cancellationToken)
    {
        Reads++;
        return Task.FromResult(Users.SingleOrDefault(user => user.NormalizedEmail == normalizedEmail));
    }
    public Task<string> GetUserIdAsync(ApplicationUser user, CancellationToken cancellationToken) => Task.FromResult(user.Id);
    public Task<string?> GetUserNameAsync(ApplicationUser user, CancellationToken cancellationToken) => Task.FromResult(user.UserName);
    public Task<string?> GetNormalizedUserNameAsync(ApplicationUser user, CancellationToken cancellationToken) => Task.FromResult(user.NormalizedUserName);
    public Task<string?> GetEmailAsync(ApplicationUser user, CancellationToken cancellationToken) => Task.FromResult(user.Email);
    public Task<string?> GetNormalizedEmailAsync(ApplicationUser user, CancellationToken cancellationToken) => Task.FromResult(user.NormalizedEmail);
    public Task<bool> GetEmailConfirmedAsync(ApplicationUser user, CancellationToken cancellationToken) => Task.FromResult(user.EmailConfirmed);
    public Task<string?> GetPasswordHashAsync(ApplicationUser user, CancellationToken cancellationToken) => Task.FromResult(user.PasswordHash);
    public Task<bool> HasPasswordAsync(ApplicationUser user, CancellationToken cancellationToken) => Task.FromResult(user.PasswordHash is not null);
    public Task<string?> GetSecurityStampAsync(ApplicationUser user, CancellationToken cancellationToken) => Task.FromResult(user.SecurityStamp);

    public Task SetUserNameAsync(ApplicationUser user, string? userName, CancellationToken cancellationToken)
    {
        user.UserName = userName;
        return Task.CompletedTask;
    }
    public Task SetNormalizedUserNameAsync(ApplicationUser user, string? normalizedName, CancellationToken cancellationToken)
    {
        user.NormalizedUserName = normalizedName;
        return Task.CompletedTask;
    }
    public Task SetEmailAsync(ApplicationUser user, string? email, CancellationToken cancellationToken)
    {
        user.Email = email;
        return Task.CompletedTask;
    }
    public Task SetNormalizedEmailAsync(ApplicationUser user, string? normalizedEmail, CancellationToken cancellationToken)
    {
        user.NormalizedEmail = normalizedEmail;
        return Task.CompletedTask;
    }
    public Task SetEmailConfirmedAsync(ApplicationUser user, bool confirmed, CancellationToken cancellationToken)
    {
        user.EmailConfirmed = confirmed;
        return Task.CompletedTask;
    }
    public Task SetPasswordHashAsync(ApplicationUser user, string? passwordHash, CancellationToken cancellationToken)
    {
        user.PasswordHash = passwordHash;
        return Task.CompletedTask;
    }
    public Task SetSecurityStampAsync(ApplicationUser user, string stamp, CancellationToken cancellationToken)
    {
        user.SecurityStamp = stamp;
        return Task.CompletedTask;
    }

    public Task<DateTimeOffset?> GetLockoutEndDateAsync(ApplicationUser user, CancellationToken cancellationToken) =>
        Task.FromResult(user.LockoutEnd);

    public Task SetLockoutEndDateAsync(ApplicationUser user, DateTimeOffset? lockoutEnd, CancellationToken cancellationToken)
    {
        user.LockoutEnd = lockoutEnd;
        return Task.CompletedTask;
    }

    public Task<int> IncrementAccessFailedCountAsync(ApplicationUser user, CancellationToken cancellationToken)
    {
        user.AccessFailedCount++;
        return Task.FromResult(user.AccessFailedCount);
    }

    public Task ResetAccessFailedCountAsync(ApplicationUser user, CancellationToken cancellationToken)
    {
        user.AccessFailedCount = 0;
        return Task.CompletedTask;
    }

    public Task<int> GetAccessFailedCountAsync(ApplicationUser user, CancellationToken cancellationToken) =>
        Task.FromResult(user.AccessFailedCount);

    public Task<bool> GetLockoutEnabledAsync(ApplicationUser user, CancellationToken cancellationToken) =>
        Task.FromResult(user.LockoutEnabled);

    public Task SetLockoutEnabledAsync(ApplicationUser user, bool enabled, CancellationToken cancellationToken)
    {
        user.LockoutEnabled = enabled;
        return Task.CompletedTask;
    }

    public void Dispose() { }
}
