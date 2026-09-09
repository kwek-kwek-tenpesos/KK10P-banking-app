using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Banking.api.Migrations
{
    /// <inheritdoc />
    public partial class AddInternalTransfers : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "CK_LedgerTransactions_Operation",
                table: "LedgerTransactions");

            migrationBuilder.AddCheckConstraint(
                name: "CK_LedgerTransactions_Operation",
                table: "LedgerTransactions",
                sql: "\"Operation\" IN ('DEVELOPMENT_FUNDING', 'INTERNAL_TRANSFER')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "CK_LedgerTransactions_Operation",
                table: "LedgerTransactions");

            migrationBuilder.AddCheckConstraint(
                name: "CK_LedgerTransactions_Operation",
                table: "LedgerTransactions",
                sql: "\"Operation\" = 'DEVELOPMENT_FUNDING'");
        }
    }
}
