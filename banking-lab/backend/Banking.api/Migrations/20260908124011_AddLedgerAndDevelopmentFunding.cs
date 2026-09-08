using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Banking.api.Migrations
{
    /// <inheritdoc />
    public partial class AddLedgerAndDevelopmentFunding : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "CK_CustomerAccounts_ZeroBalance",
                table: "CustomerAccounts");

            migrationBuilder.CreateTable(
                name: "LedgerTransactions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Operation = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    InitiatedByUserId = table.Column<string>(type: "text", nullable: false),
                    IdempotencyKey = table.Column<Guid>(type: "uuid", nullable: false),
                    RequestFingerprint = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    Currency = table.Column<string>(type: "character varying(3)", maxLength: 3, nullable: false),
                    BalanceAfterMinor = table.Column<long>(type: "bigint", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_LedgerTransactions", x => x.Id);
                    table.CheckConstraint("CK_LedgerTransactions_Currency", "\"Currency\" = 'PHP'");
                    table.CheckConstraint("CK_LedgerTransactions_FingerprintLength", "char_length(\"RequestFingerprint\") = 64");
                    table.CheckConstraint("CK_LedgerTransactions_NonnegativeBalance", "\"BalanceAfterMinor\" >= 0");
                    table.CheckConstraint("CK_LedgerTransactions_Operation", "\"Operation\" = 'DEVELOPMENT_FUNDING'");
                    table.ForeignKey(
                        name: "FK_LedgerTransactions_AspNetUsers_InitiatedByUserId",
                        column: x => x.InitiatedByUserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "LedgerPostings",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    LedgerTransactionId = table.Column<Guid>(type: "uuid", nullable: false),
                    Position = table.Column<short>(type: "smallint", nullable: false),
                    CustomerAccountId = table.Column<Guid>(type: "uuid", nullable: true),
                    BookAccount = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    AmountMinor = table.Column<long>(type: "bigint", nullable: false),
                    Currency = table.Column<string>(type: "character varying(3)", maxLength: 3, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_LedgerPostings", x => x.Id);
                    table.CheckConstraint("CK_LedgerPostings_BookAccount", "\"BookAccount\" IS NULL OR \"BookAccount\" = 'SIMULATOR_ISSUER'");
                    table.CheckConstraint("CK_LedgerPostings_Currency", "\"Currency\" = 'PHP'");
                    table.CheckConstraint("CK_LedgerPostings_ExactlyOneAccount", "(\"CustomerAccountId\" IS NOT NULL)::int + (\"BookAccount\" IS NOT NULL)::int = 1");
                    table.CheckConstraint("CK_LedgerPostings_NonzeroAmount", "\"AmountMinor\" <> 0");
                    table.CheckConstraint("CK_LedgerPostings_Position", "\"Position\" IN (1, 2)");
                    table.ForeignKey(
                        name: "FK_LedgerPostings_CustomerAccounts_CustomerAccountId",
                        column: x => x.CustomerAccountId,
                        principalTable: "CustomerAccounts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_LedgerPostings_LedgerTransactions_LedgerTransactionId",
                        column: x => x.LedgerTransactionId,
                        principalTable: "LedgerTransactions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.AddCheckConstraint(
                name: "CK_CustomerAccounts_NonnegativeBalance",
                table: "CustomerAccounts",
                sql: "\"BalanceMinor\" >= 0");

            migrationBuilder.CreateIndex(
                name: "IX_LedgerPostings_CustomerAccountId",
                table: "LedgerPostings",
                column: "CustomerAccountId");

            migrationBuilder.CreateIndex(
                name: "IX_LedgerPostings_LedgerTransactionId_Position",
                table: "LedgerPostings",
                columns: new[] { "LedgerTransactionId", "Position" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_LedgerTransactions_CreatedAtUtc",
                table: "LedgerTransactions",
                column: "CreatedAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_LedgerTransactions_InitiatedByUserId_IdempotencyKey",
                table: "LedgerTransactions",
                columns: new[] { "InitiatedByUserId", "IdempotencyKey" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "LedgerPostings");

            migrationBuilder.DropTable(
                name: "LedgerTransactions");

            migrationBuilder.DropCheckConstraint(
                name: "CK_CustomerAccounts_NonnegativeBalance",
                table: "CustomerAccounts");

            migrationBuilder.AddCheckConstraint(
                name: "CK_CustomerAccounts_ZeroBalance",
                table: "CustomerAccounts",
                sql: "\"BalanceMinor\" = 0");
        }
    }
}
