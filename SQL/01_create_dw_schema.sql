--------------------------------------------------------------------------------
-- EFG_DW Database & Star Schema Setup Script
-- Project 1: Monthly Summary Dashboard with ETL & Star Schema
--------------------------------------------------------------------------------

USE master;
GO

-- 1. Create Database if not exists
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'EFG_DW')
BEGIN
    CREATE DATABASE EFG_DW;
    PRINT 'Database EFG_DW created successfully.';
END
ELSE
BEGIN
    PRINT 'Database EFG_DW already exists.';
END
GO

USE EFG_DW;
GO

-- 2. Create Schemas
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'stg')
BEGIN
    EXEC('CREATE SCHEMA stg AUTHORIZATION dbo;');
    PRINT 'Schema stg created.';
END
GO

--------------------------------------------------------------------------------
-- 3. Staging Layer Tables (stg)
--------------------------------------------------------------------------------

IF OBJECT_ID('stg.Customers', 'U') IS NOT NULL DROP TABLE stg.Customers;
CREATE TABLE stg.Customers (
    CustomerID NVARCHAR(50) NULL,
    City       NVARCHAR(100) NULL,
    AgeGroup   NVARCHAR(50) NULL,
    SignupDate NVARCHAR(50) NULL
);
GO

IF OBJECT_ID('stg.Products', 'U') IS NOT NULL DROP TABLE stg.Products;
CREATE TABLE stg.Products (
    ProductID NVARCHAR(50) NULL,
    Category  NVARCHAR(100) NULL,
    ListPrice NVARCHAR(50) NULL,
    Cost      NVARCHAR(50) NULL
);
GO

IF OBJECT_ID('stg.Orders', 'U') IS NOT NULL DROP TABLE stg.Orders;
CREATE TABLE stg.Orders (
    OrderID    NVARCHAR(50) NULL,
    CustomerID NVARCHAR(50) NULL,
    ProductID  NVARCHAR(50) NULL,
    Quantity   NVARCHAR(50) NULL,
    OrderDate  NVARCHAR(50) NULL,
    Channel    NVARCHAR(50) NULL
);
GO

--------------------------------------------------------------------------------
-- 4. Star Schema Dimension Tables (dbo)
--------------------------------------------------------------------------------

-- Clean up Fact table before Dimensions if already existing
IF OBJECT_ID('dbo.Fact_Sales', 'U') IS NOT NULL DROP TABLE dbo.Fact_Sales;
GO

-- Dim_Channel
IF OBJECT_ID('dbo.Dim_Channel', 'U') IS NOT NULL DROP TABLE dbo.Dim_Channel;
CREATE TABLE dbo.Dim_Channel (
    ChannelSK    INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ChannelName  NVARCHAR(50) NOT NULL UNIQUE
);
GO

-- Dim_Region
IF OBJECT_ID('dbo.Dim_Region', 'U') IS NOT NULL DROP TABLE dbo.Dim_Region;
CREATE TABLE dbo.Dim_Region (
    RegionSK     INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    City         NVARCHAR(100) NOT NULL UNIQUE,
    Region       NVARCHAR(100) NOT NULL
);
GO

-- Dim_Customer
IF OBJECT_ID('dbo.Dim_Customer', 'U') IS NOT NULL DROP TABLE dbo.Dim_Customer;
CREATE TABLE dbo.Dim_Customer (
    CustomerSK   INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    CustomerID   NVARCHAR(50) NOT NULL,
    City         NVARCHAR(100) NULL,
    Region       NVARCHAR(100) NULL,
    AgeGroup     NVARCHAR(50) NULL,
    SignupDate   DATE NULL,
    CreatedDate  DATETIME DEFAULT GETDATE(),
    ModifiedDate DATETIME DEFAULT GETDATE()
);
CREATE UNIQUE NONCLUSTERED INDEX UQ_Dim_Customer_CustomerID ON dbo.Dim_Customer(CustomerID);
GO

-- Dim_Product
IF OBJECT_ID('dbo.Dim_Product', 'U') IS NOT NULL DROP TABLE dbo.Dim_Product;
CREATE TABLE dbo.Dim_Product (
    ProductSK    INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ProductID    NVARCHAR(50) NOT NULL,
    Category     NVARCHAR(100) NULL,
    ListPrice    DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    Cost         DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    Margin       DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    MarginPct    DECIMAL(5,2)  NOT NULL DEFAULT 0.00,
    CreatedDate  DATETIME DEFAULT GETDATE(),
    ModifiedDate DATETIME DEFAULT GETDATE()
);
CREATE UNIQUE NONCLUSTERED INDEX UQ_Dim_Product_ProductID ON dbo.Dim_Product(ProductID);
GO

-- Dim_Date
IF OBJECT_ID('dbo.Dim_Date', 'U') IS NOT NULL DROP TABLE dbo.Dim_Date;
CREATE TABLE dbo.Dim_Date (
    DateSK       INT NOT NULL PRIMARY KEY,       -- Format: YYYYMMDD
    FullDate     DATE NOT NULL UNIQUE,
    Day          INT NOT NULL,
    DayName      NVARCHAR(20) NOT NULL,
    Month        INT NOT NULL,
    MonthName    NVARCHAR(20) NOT NULL,
    Quarter      INT NOT NULL,
    QuarterName  NVARCHAR(10) NOT NULL,
    Year         INT NOT NULL,
    IsWeekend    BIT NOT NULL
);
GO

--------------------------------------------------------------------------------
-- 5. Fact Table (dbo.Fact_Sales)
--------------------------------------------------------------------------------

CREATE TABLE dbo.Fact_Sales (
    SalesSK      BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    OrderID      NVARCHAR(50) NOT NULL,
    DateSK       INT NOT NULL,
    CustomerSK   INT NOT NULL,
    ProductSK    INT NOT NULL,
    ChannelSK    INT NOT NULL,
    Quantity     INT NOT NULL,
    ListPrice    DECIMAL(12,2) NOT NULL,
    Cost         DECIMAL(12,2) NOT NULL,
    TotalSales   DECIMAL(12,2) NOT NULL,
    TotalCost    DECIMAL(12,2) NOT NULL,
    GrossProfit  DECIMAL(12,2) NOT NULL,
    LoadedDate   DATETIME DEFAULT GETDATE(),

    CONSTRAINT FK_FactSales_Date FOREIGN KEY (DateSK) REFERENCES dbo.Dim_Date(DateSK),
    CONSTRAINT FK_FactSales_Customer FOREIGN KEY (CustomerSK) REFERENCES dbo.Dim_Customer(CustomerSK),
    CONSTRAINT FK_FactSales_Product FOREIGN KEY (ProductSK) REFERENCES dbo.Dim_Product(ProductSK),
    CONSTRAINT FK_FactSales_Channel FOREIGN KEY (ChannelSK) REFERENCES dbo.Dim_Channel(ChannelSK)
);
GO

CREATE NONCLUSTERED INDEX IX_FactSales_DateSK ON dbo.Fact_Sales(DateSK);
CREATE NONCLUSTERED INDEX IX_FactSales_CustomerSK ON dbo.Fact_Sales(CustomerSK);
CREATE NONCLUSTERED INDEX IX_FactSales_ProductSK ON dbo.Fact_Sales(ProductSK);
CREATE NONCLUSTERED INDEX IX_FactSales_ChannelSK ON dbo.Fact_Sales(ChannelSK);
GO

--------------------------------------------------------------------------------
-- 6. Populate Initial Seed Data (Dim_Region & Dim_Channel)
--------------------------------------------------------------------------------

-- Populate Regional groupings for Egyptian cities in dataset
INSERT INTO dbo.Dim_Region (City, Region)
VALUES 
    (N'Cairo', N'Greater Cairo'),
    (N'Giza', N'Greater Cairo'),
    (N'Alexandria', N'Alexandria & North Coast'),
    (N'Tanta', N'Delta');
GO

-- Populate Channels
INSERT INTO dbo.Dim_Channel (ChannelName)
VALUES 
    (N'Subscription'),
    (N'One-time');
GO

--------------------------------------------------------------------------------
-- 7. Populate Dim_Date (2024-01-01 to 2026-12-31)
--------------------------------------------------------------------------------

DECLARE @StartDate DATE = '2024-01-01';
DECLARE @EndDate   DATE = '2026-12-31';

WITH DateSequence AS (
    SELECT @StartDate AS [Date]
    UNION ALL
    SELECT DATEADD(DAY, 1, [Date])
    FROM DateSequence
    WHERE [Date] < @EndDate
)
INSERT INTO dbo.Dim_Date (
    DateSK,
    FullDate,
    Day,
    DayName,
    Month,
    MonthName,
    Quarter,
    QuarterName,
    Year,
    IsWeekend
)
SELECT
    CAST(FORMAT([Date], 'yyyyMMdd') AS INT) AS DateSK,
    [Date] AS FullDate,
    DATEPART(DAY, [Date]) AS Day,
    DATENAME(WEEKDAY, [Date]) AS DayName,
    DATEPART(MONTH, [Date]) AS Month,
    DATENAME(MONTH, [Date]) AS MonthName,
    DATEPART(QUARTER, [Date]) AS Quarter,
    CONCAT('Q', DATEPART(QUARTER, [Date])) AS QuarterName,
    DATEPART(YEAR, [Date]) AS Year,
    CASE WHEN DATEPART(WEEKDAY, [Date]) IN (6, 7) THEN 1 ELSE 0 END AS IsWeekend -- Fri/Sat or Sat/Sun depending on DATEFIRST
FROM DateSequence
OPTION (MAXRECURSION 2000);
GO

PRINT 'Star schema and Dim_Date generation complete.';
GO
