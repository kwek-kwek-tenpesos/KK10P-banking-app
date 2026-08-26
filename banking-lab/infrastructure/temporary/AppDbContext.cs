using Microsoft.EntityFrameworkCore;

namespace banking_lab.infrastructure.temporary;
public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
    {
    }
    public DbSet<SetupProbe> SetupProbes { get; set; }
}

public class SetupProbe
{
    public int Id { get; set; }
    public string Status { get; set; } = "Connection Verified";
    public DateTime CheckedAt { get; set; } = DateTime.UtcNow;
}