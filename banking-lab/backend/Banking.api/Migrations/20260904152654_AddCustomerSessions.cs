using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Banking.api.Migrations
{
    /// <inheritdoc />
    public partial class AddCustomerSessions : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "SessionId",
                table: "CustomerRefreshTokens",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "CustomerSessions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<string>(type: "text", nullable: false),
                    SecurityStamp = table.Column<string>(type: "text", nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    LastActivityAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    IdleExpiresAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    AbsoluteExpiresAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    RevokedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    Version = table.Column<Guid>(type: "uuid", nullable: false),
                    RefreshWindowStartedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    RefreshWindowCount = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CustomerSessions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CustomerSessions_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_CustomerRefreshTokens_SessionId",
                table: "CustomerRefreshTokens",
                column: "SessionId");

            migrationBuilder.CreateIndex(
                name: "IX_CustomerSessions_UserId",
                table: "CustomerSessions",
                column: "UserId");

            migrationBuilder.AddForeignKey(
                name: "FK_CustomerRefreshTokens_CustomerSessions_SessionId",
                table: "CustomerRefreshTokens",
                column: "SessionId",
                principalTable: "CustomerSessions",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_CustomerRefreshTokens_CustomerSessions_SessionId",
                table: "CustomerRefreshTokens");

            migrationBuilder.DropTable(
                name: "CustomerSessions");

            migrationBuilder.DropIndex(
                name: "IX_CustomerRefreshTokens_SessionId",
                table: "CustomerRefreshTokens");

            migrationBuilder.DropColumn(
                name: "SessionId",
                table: "CustomerRefreshTokens");
        }
    }
}
