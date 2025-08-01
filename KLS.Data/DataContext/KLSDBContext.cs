using KLS.Common;
using KLS.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Data.DataContext
{
    public class KLSDBContext : DbContext
    {
        public KLSDBContext()
        {
            Database.SetCommandTimeout(600);
        }

        protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
        {
            if (!optionsBuilder.IsConfigured)
            {
                var connectionString = Constants.ConnectionString;
                optionsBuilder.UseSqlServer(connectionString);
            }
        }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<Holiday>().ToTable("Holidays");
            modelBuilder.Entity<UserRole>().ToTable("UserRoles");
            modelBuilder.Entity<User>().ToTable("Users");
            modelBuilder.Entity<Employee>().ToTable("Employees");
            modelBuilder.Entity<Customer>().ToTable("Customers");
            modelBuilder.Entity<Vendor>().ToTable("Vendors");
            modelBuilder.Entity<Term>().ToTable("Terms");
            modelBuilder.Entity<Truck>().ToTable("Trucks");
            modelBuilder.Entity<ChartOfAccountType>().ToTable("ChartOfAccountTypes");
            modelBuilder.Entity<ChartOfAccount>().ToTable("ChartOfAccounts");
            modelBuilder.Entity<EmailLog>().ToTable("EmailLogs");
            modelBuilder.Entity<RecalculationLog>().ToTable("RecalculationLogs");
            modelBuilder.Entity<GeneralJournal>().ToTable("GeneralJournals");
            modelBuilder.Entity<GeneralJournalDetail>().ToTable("GeneralJournalDetails");
            modelBuilder.Entity<TempGeneralJournal>().ToTable("TempGeneralJournals");
            modelBuilder.Entity<SystemSetting>().ToTable("SystemSettings");

            modelBuilder.Entity<Payee>().ToTable("Payees");
            modelBuilder.Entity<Payee>().Property(c => c.PayeeId).ValueGeneratedNever();
            modelBuilder.Entity<Payee>().Property(c => c.Id).Metadata.SetAfterSaveBehavior(PropertySaveBehavior.Ignore);
        }

        #region ---DBSET---

        public DbSet<Holiday> Holidays { get; set; }

        public DbSet<UserRole> UserRoles { get; set; }

        public DbSet<Payee> Payees { get; set; }

        public DbSet<User> Users { get; set; }

        public DbSet<Employee> Employees { get; set; }

        public DbSet<Customer> Customers { get; set; }

        public DbSet<Vendor> Vendors { get; set; }

        public DbSet<Term> Temrs { get; set; }

        public DbSet<Truck> Trucks { get; set; }

        public DbSet<ChartOfAccountType> ChartOfAccountTypes { get; set; }

        public DbSet<ChartOfAccount> ChartOfAccounts { get; set; }

        public DbSet<EmailLogDTO> EmailLogDTO { get; set; }

        public DbSet<RecalculationLog> RecalculationLogs { get; set; }

        public DbSet<GeneralJournal> GeneralJournals { get; set; }

        public DbSet<GeneralJournalDetail> GeneralJournalDetails { get; set; }

        public DbSet<TempGeneralJournal> TempGeneralJournals { get; set; }

        #endregion
    }
}