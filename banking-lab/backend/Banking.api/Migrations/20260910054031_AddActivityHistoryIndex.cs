using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Banking.api.Migrations
{
    /// <inheritdoc />
    public partial class AddActivityHistoryIndex : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "IX_LedgerPostings_Account_CreatedAt_Transaction",
                table: "LedgerPostings",
                columns: new[] { "CustomerAccountId", "CreatedAtUtc", "LedgerTransactionId" },
                descending: new[] { false, true, true });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_LedgerPostings_Account_CreatedAt_Transaction",
                table: "LedgerPostings");
        }
    }
}
