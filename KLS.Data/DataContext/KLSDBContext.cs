using KLS.Common;
using KLS.Models;
using KLS.Models.Deposit;
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

            modelBuilder.Entity<Holiday>().ToTable("Holiday");
            modelBuilder.Entity<SystemRole>().ToTable("SystemRole");
            modelBuilder.Entity<SystemUser>().ToTable("SystemUser");
            modelBuilder.Entity<Employee>().ToTable("Employee");
            modelBuilder.Entity<EmailSetting>().ToTable("EmailSetting");
            modelBuilder.Entity<Customer>().ToTable("Customer");
            modelBuilder.Entity<Vendor>().ToTable("Vendor");
            modelBuilder.Entity<Term>().ToTable("Term");
            modelBuilder.Entity<Truck>().ToTable("Truck");
            modelBuilder.Entity<AccountType>().ToTable("AccountType");
            modelBuilder.Entity<Account>().ToTable("Account");
            modelBuilder.Entity<EmailLog>().ToTable("EmailLog");
            modelBuilder.Entity<RecalculationLog>().ToTable("RecalculationLog");
            modelBuilder.Entity<GeneralJournal>().ToTable("GeneralJournal");
            modelBuilder.Entity<GeneralJournalDetail>().ToTable("GeneralJournalDetail");
            modelBuilder.Entity<TempGeneralJournal>().ToTable("TempGeneralJournal");
            modelBuilder.Entity<ItemCategory>().ToTable("ItemCategory");
            modelBuilder.Entity<SystemSetting>().ToTable("SystemSetting");
            modelBuilder.Entity<TransferFund>().ToTable("TransferFund");
            modelBuilder.Entity<Transaction>().ToTable("TransactionJournal");
            modelBuilder.Entity<TransactionDetail>().ToTable("TransactionJournalDetail");
            modelBuilder.Entity<SourceDocType>().ToTable("SourceDocType");
            modelBuilder.Entity<ItemStorage>().ToTable("ItemStorage");
            modelBuilder.Entity<Sales>().ToTable("Sales");
            modelBuilder.Entity<DeleteLog>().ToTable("DeleteLog");
            modelBuilder.Entity<Company>().ToTable("Company");
            modelBuilder.Entity<BankRecon>().ToTable("BankRecon");
            modelBuilder.Entity<VendorPayment>().ToTable("VendorPayment");
            modelBuilder.Entity<PaymentOption>().ToTable("PaymentOption");            
            modelBuilder.Entity<Timesheet>().ToTable("Timesheet");
            modelBuilder.Entity<TimesheetDetail>().ToTable("TimesheetDetail");
            modelBuilder.Entity<TempTimesheet>().ToTable("TempTimesheet");
            modelBuilder.Entity<PayrollService>().ToTable("PayrollService");
            modelBuilder.Entity<PayrollServiceDetail>().ToTable("PayrollServiceDetail");
            modelBuilder.Entity<PayrollServiceType>().ToTable("PayrollServiceType");
            modelBuilder.Entity<TempPayrollService>().ToTable("TempPayrollService");
            modelBuilder.Entity<PayrollDetail>().ToTable("PayrollDetail");
            modelBuilder.Entity<TempPayrollDetail>().ToTable("TempPayrollDetail");
            modelBuilder.Entity<CustomerPayment>().ToTable("CustomerPayment");
            modelBuilder.Entity<Item>().ToTable("Item");

            modelBuilder.Entity<EmpJob>().ToTable("EmpJob");
            modelBuilder.Entity<EmpJob>().Property(c => c.JobCode).ValueGeneratedNever();
            modelBuilder.Entity<EmpJob>().Property(c => c.JobId).Metadata.SetAfterSaveBehavior(PropertySaveBehavior.Ignore);

            modelBuilder.Entity<Payee>().ToTable("Payee");
            modelBuilder.Entity<Payee>().Property(c => c.PayeeId).ValueGeneratedNever();
            modelBuilder.Entity<Payee>().Property(c => c.Id).Metadata.SetAfterSaveBehavior(PropertySaveBehavior.Ignore);
        }

        #region ---DBSET---

        public DbSet<Holiday> Holidays { get; set; }

        public DbSet<SystemRole> SystemRoles { get; set; }

        public DbSet<Payee> Payees { get; set; }

        public DbSet<SystemUser> SystemUsers { get; set; }

        public DbSet<EmailSetting> EmailSettings { get; set; }

        public DbSet<Employee> Employees { get; set; }

        public DbSet<Customer> Customers { get; set; }

        public DbSet<Vendor> Vendors { get; set; }

        public DbSet<Term> Temrs { get; set; }

        public DbSet<Truck> Trucks { get; set; }

        public DbSet<AccountType> AccountTypes { get; set; }

        public DbSet<Account> Accounts { get; set; }

        public DbSet<EmailLog> EmailLogs { get; set; }

        public DbSet<RecalculationLog> RecalculationLogs { get; set; }

        public DbSet<GeneralJournal> GeneralJournals { get; set; }

        public DbSet<GeneralJournalDetail> GeneralJournalDetails { get; set; }

        public DbSet<TempGeneralJournal> TempGeneralJournals { get; set; }

        public DbSet<ItemCategory> ItemCategories { get; set; }

        public DbSet<SystemSetting> SystemSettings { get; set; }

        public DbSet<TransferFund> TransferFunds { get; set; }

        public DbSet<Transaction> Transactions { get; set; }

        public DbSet<TransactionDetail> TransactionDetails { get; set; }

        public DbSet<SourceDocType> SourceDocTypes { get; set; }

        public DbSet<ItemStorage> ItemStorages { get; set; }

        public DbSet<Timesheet> Timesheets { get; set; }

        public DbSet<Sales> Sales { get; set; }

        public DbSet<DeleteLog> DeleteLogs { get; set; }

        public DbSet<Company> Companies { get; set; }

        public DbSet<BankRecon> BankRecons { get; set; }

        public DbSet<VendorPayment> VendorPayments { get; set; }

        public DbSet<PaymentOption> PaymentOptions { get; set; }

        public DbSet<PayrollService> PayrollServices { get; set; }

        public DbSet<TimesheetDetail> TimesheetDetails { get; set; }

        public DbSet<TempTimesheet> TempTimesheets { get; set; }

        public DbSet<PayrollServiceDetail> PayrollServiceDetails { get; set; }

        public DbSet<PayrollServiceType> PayrollServiceTypes { get; set; }

        public DbSet<EmpJob> EmpJobs { get; set; }

        public DbSet<TempPayrollService> TempPayrollServices { get; set; }

        public DbSet<PayrollDetail> payrollDetails { get; set; }

        public DbSet<TempPayrollDetail> TempPayrollDetails { get; set; }

        public DbSet<CustomerPayment> CustomerPayments { get; set; }

        public DbSet<Item> Items { get; set; }

        #endregion

        #region ---Virtual DBSET---

        public virtual DbSet<EmailLogDTO> EmailLogDTO { get; set; }

        public virtual DbSet<AccountDTO> AccountDTO { get; set; }

        public virtual DbSet<CreditDebitAmount> CreditDebitAmount { get; set; }

        public virtual DbSet<TempGeneralJournalList> TempGeneralJournalList { get; set; }

        public virtual DbSet<TransferFundList> TransferFundList { get; set; }

        public virtual DbSet<DepositList> DepositList { get; set; }

        public virtual DbSet<EmployeeList> EmployeeList { get; set; }

        public virtual DbSet<PayeeSearch> PayeeSearch { get; set; }

        public virtual DbSet<VendorSearchDTO> VendorSearchDTO { get; set; }

        public virtual DbSet<CheckRegister> CheckRegister { get; set; }

        public virtual DbSet<EmployeeAdvancePmt> EmployeeAdvancePmts { get; set; }

        public virtual DbSet<PayrollServiceDTO> PayrollServiceDTO { get; set; }

        public virtual DbSet<VendorPaymentList> VendorPaymentList { get; set; }

        public virtual DbSet<PayrollList> PayrollList { get; set; }

        public virtual DbSet<CheckInOut> CheckInOut { get; set; }

        public virtual DbSet<CustomerPaymentList> CustomerPaymentList { get; set; }

        public virtual DbSet<IncomingPaymentList> IncomingPaymentList { get; set; }

        #endregion
    }
}