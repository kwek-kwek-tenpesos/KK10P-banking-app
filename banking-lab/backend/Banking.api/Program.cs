using banking_lab.infrastructure.temporary;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Register your AppDbContext using the connection string configuration key
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

var app = builder.Build();

app.MapGet("/api/v1/system/info", (IWebHostEnvironment env) =>
    Results.Ok(new {
        name = "Banking API",
        version = "v1.0.0",
        environment = env.EnvironmentName
    }));

app.Run();
