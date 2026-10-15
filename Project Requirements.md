# Project 1: Monthly Summary Dashboard with ETL & Star Schema

## 🎯 Project Overview & Objective

Welcome to your first Business Intelligence project! In this project, you will step into the shoes of a BI Developer at EFG Holding. You will design, build, and deploy an automated end-to-end data pipeline: from raw source files to a relational Data Warehouse, orchestrating ETL workflows using **SQL Server Integration Services (SSIS)**, and presenting executive insights in **Power BI**.

Your goal is to build an interactive **Monthly Summary Dashboard** backed by a clean **Star Schema** data warehouse.

---

## 🛠️ Prerequisites & Required Tools

Before you begin, ensure you have the following installed on your machine:
* **Microsoft SQL Server (2019 or newer / SQL Server Express)**
* **SQL Server Management Studio (SSMS)**
* **Visual Studio 2022** with **SQL Server Integration Services Projects (SSIS)** extension
* **Microsoft Power BI Desktop**

---

## 📂 Source Data Profile

The raw transactional data is provided as CSV files inside the [`Data/`](file:///c:/Users/menna/Desktop/Wahba/BI%20Projects/Project%201/Data) directory:

| File | Primary Key | Description | Key Columns |
| :--- | :--- | :--- | :--- |
| **`customers.csv`** | `CustomerID` | Customer demographics & signups | `CustomerID`, `City`, `AgeGroup`, `SignupDate` |
| **`products.csv`** | `ProductID` | Product catalog with price & cost | `ProductID`, `Category`, `ListPrice`, `Cost` |
| **`orders.csv`** | `OrderID` | Transactional customer orders | `OrderID`, `CustomerID`, `ProductID`, `Quantity`, `OrderDate`, `Channel` |

> [!NOTE]
> Some order records may contain dates or foreign keys that need careful validation during ETL. Your pipeline should identify and handle unmatched or erroneous records without crashing.

---

## 📋 Step-by-Step Implementation Tasks

Follow this structured 4-phase roadmap to build the project from scratch:

```mermaid
flowchart LR
    P1["<b>Phase 1</b><br/>Requirements & Star Schema Design"] --> P2["<b>Phase 2</b><br/>SQL Server DW Setup (DDL)"]
    P2 --> P3["<b>Phase 3</b><br/>SSIS ETL Pipeline Development"]
    P3 --> P4["<b>Phase 4</b><br/>Power BI Dashboard & DAX"]
```

---

### Phase 1: Requirements Gathering & Star Schema Design

1. **Analyze Reporting Needs & Business Questions**:
   * What is our total revenue, total product cost, and gross profit margin?
   * How are sales trending month-over-month (MoM)?
   * Which product categories and individual products generate the highest revenue?
   * How do sales vary across customer cities and age brackets?
   * How does order volume compare between sales channels (e.g., Subscription vs. One-time)?

2. **Design the Star Schema**:
   * **Fact Table (`Fact_Sales`)**: The grain is **one row per order line**. Identify all numeric measures (Quantity, ListPrice, Cost, TotalSales, TotalCost, GrossProfit) and foreign keys.
   * **Dimension Tables**:
     * `Dim_Customer`: Customer attributes (`CustomerID`, `City`, `AgeGroup`, `SignupDate`).
     * `Dim_Product`: Product details and profitability (`ProductID`, `Category`, `ListPrice`, `Cost`, `Margin`, `MarginPct`).
     * `Dim_Date`: Calendar dimension to support Power BI Time Intelligence (`DateSK`, `FullDate`, `Day`, `Month`, `MonthName`, `Quarter`, `Year`, `IsWeekend`).
     * `Dim_Region`: Geographic grouping based on customer cities (e.g., Greater Cairo, Alexandria, Delta).
     * `Dim_Channel`: Sales channels (e.g., Subscription vs One-time).
   * **Surrogate Keys**: Use integer surrogate keys (`IDENTITY(1,1)`) for all dimensions to isolate the warehouse from natural business keys.
   * **Draw the Entity-Relationship Diagram (ERD)** documenting primary-to-foreign key relationships.

---

### Phase 2: SQL Server Data Warehouse Setup

1. **Create Database & Schemas**:
   * Create a new SQL Server database named `EFG_DW`.
   * Create two schemas:
     * `stg`: For temporary staging tables holding raw ingested CSV data.
     * `dbo`: For the star schema dimension and fact tables.

2. **Create Staging Tables**:
   * Build `stg.Customers`, `stg.Products`, and `stg.Orders` mirroring the CSV file structure.

3. **Create Dimension Tables (`dbo.*`)**:
   * Build `dbo.Dim_Customer`, `dbo.Dim_Product`, `dbo.Dim_Region`, `dbo.Dim_Channel`.
   * Include audit columns (`CreatedDate`, `ModifiedDate`) where appropriate.

4. **Generate the `Dim_Date` Table**:
   * Write a T-SQL loop or script to generate dates covering from `2024-01-01` to `2026-12-31`.
   * Ensure `DateSK` is in integer format (`YYYYMMDD`, e.g. `20240901`) to enable fast join performance.

5. **Create Fact Table (`dbo.Fact_Sales`)**:
   * Define foreign keys pointing to `Dim_Date(DateSK)`, `Dim_Customer(CustomerSK)`, `Dim_Product(ProductSK)`, and `Dim_Channel(ChannelSK)`.
   * Define measures: `Quantity`, `ListPrice`, `Cost`, `TotalSales`, `TotalCost`, `GrossProfit`.
   * Add proper primary key, foreign key constraints, and non-clustered indexes on all foreign key columns.

---

### Phase 3: SSIS ETL Development

Launch Visual Studio and create a new **Integration Services Project**. Your ETL pipeline must follow standard data warehouse staging and loading practices:

```mermaid
flowchart TD
    subgraph Staging Layer
        CSV[Source CSV Files] --> StgCust[Load_Stg_Customer.dtsx]
        CSV --> StgProd[Load_Stg_Products.dtsx]
        CSV --> StgOrd[Load_Stg_Orders.dtsx]
    end

    subgraph Dimension Layer
        StgCust --> DimCust[Load_Dim_Customer.dtsx]
        StgProd --> DimProd[Load_Dim_Product.dtsx]
    end

    subgraph Fact Layer
        StgOrd --> FactSales[Load_Fact_Sales.dtsx]
        DimCust -.-> FactSales
        DimProd -.-> FactSales
    end

    Master[Master.dtsx Orchestrator] --> Staging Layer
    Staging Layer --> Dimension Layer
    Dimension Layer --> Fact Layer
```

1. **Connection Managers**:
   * Configure **Flat File Connection Managers** for each CSV.
   * Configure an **OLE DB Connection Manager** connecting to `EFG_DW`.

2. **Staging Packages (`Load_Stg_*.dtsx`)**:
   * Truncate staging tables before each run.
   * Read raw CSV rows.
   * Use **Derived Column** transformations to trim whitespace from text strings.
   * Use **Data Conversion** transformations to cast data types safely before insertion.
   * Use **Sort** (or SQL grouping) to eliminate duplicate records.

3. **Dimension Packages (`Load_Dim_*.dtsx`)**:
   * Implement **SCD Type 1 (Slowly Changing Dimension)** logic:
     * Use a **Lookup Transformation** to check if the natural key (`CustomerID`, `ProductID`) exists in the dimension table.
     * New records (No-Match output) $\to$ Insert into Dimension.
     * Existing records (Match output) $\to$ Update attributes if changed.
   * In `Load_Dim_Product.dtsx`, calculate `Margin` and `MarginPct` using a Derived Column task.

4. **Fact Load Package (`Load_Fact_Sales.dtsx`)**:
   * Source: `stg.Orders`.
   * **Lookup 1**: Match `OrderDate` $\to$ `Dim_Date.DateSK`.
   * **Lookup 2**: Match `CustomerID` $\to$ `Dim_Customer.CustomerSK`.
   * **Lookup 3**: Match `ProductID` $\to$ `Dim_Product.ProductSK` (and retrieve `ListPrice` and `Cost`).
   * **Lookup 4**: Match `Channel` $\to$ `Dim_Channel.ChannelSK`.
   * **Derived Column**: Compute:
     $$\text{TotalSales} = \text{Quantity} \times \text{ListPrice}$$
     $$\text{TotalCost} = \text{Quantity} \times \text{Cost}$$
     $$\text{GrossProfit} = \text{TotalSales} - \text{TotalCost}$$
   * **Error Handling**: Redirect unmapped or unmatched records into an error table or flat file for data auditing.

5. **Master Orchestrator Package (`Master.dtsx`)**:
   * Use **Execute Package Tasks** to orchestrate the entire workflow.
   * Use **Precedence Constraints** (Success dependency) to ensure:
     $$\text{Staging Packages} \longrightarrow \text{Dimension Packages} \longrightarrow \text{Fact Package}$$
   * Configure logging and an `OnError` event handler to track pipeline execution times and failures.

---

### Phase 4: Power BI Dashboard & DAX Development

Connect Power BI Desktop to `EFG_DW` and build an executive analytics dashboard:

1. **Data Model Configuration**:
   * Verify all 1-to-many relationships in Model View.
   * Mark `Dim_Date` as a formal Date Table using `FullDate`.
   * Hide surrogate keys (`CustomerSK`, `ProductSK`, etc.) from Report View.

2. **Core DAX Measures**:
   Create a dedicated `_Measures` table and write measures for:
   * **Total Revenue**: $\sum(\text{TotalSales})$
   * **Total Cost**: $\sum(\text{TotalCost})$
   * **Gross Profit**: $\text{Total Revenue} - \text{Total Cost}$
   * **Gross Margin %**: $\frac{\text{Gross Profit}}{\text{Total Revenue}} \times 100$
   * **Total Orders**: Distinct count of `OrderID`
   * **Average Order Value (AOV)**: $\frac{\text{Total Revenue}}{\text{Total Orders}}$
   * **Prior Month Revenue**: Using `CALCULATE` and `PREVIOUSMONTH`
   * **MoM Revenue Growth %**: Percentage change vs previous month

3. **Required Dashboard Pages**:
   * **Page 1: Executive Summary**:
     * KPI Cards: Total Revenue, Gross Profit, Total Orders, Gross Margin %.
     * Monthly Revenue Trend (Line Chart) with MoM Growth.
     * Top-level slicers for Date range and Sales Channel.
   * **Page 2: Product & Category Performance**:
     * Revenue by Category (Bar Chart).
     * Top Products by Revenue.
     * Category Margin % breakdown.
   * **Page 3: Customer & Geographic Analysis**:
     * Revenue by City/Region (Map or Clustered Bar).
     * Customer distribution across Age Groups.
     * New Customer Signups over time.
   * **Page 4: Channel Analysis**:
     * Subscription vs. One-Time revenue breakdown.
     * Average Order Value by Channel.
     * Channel trend over time.

---

## 🏆 Deliverables & Success Checklist

When your project is ready for submission, verify that you have:
- [ ] Working SQL DDL scripts creating `EFG_DW`, staging, and star schema tables.
- [ ] Populated `Dim_Date` table with complete calendar attributes.
- [ ] Complete SSIS solution with Staging, Dimension, Fact, and Master packages.
- [ ] Successful end-to-end execution of `Master.dtsx` without errors.
- [ ] Published Power BI report file (`.pbix`) with all 4 required pages and interactive cross-filtering.

---

> [!TIP]
> Once you have attempted the project, or if you need to reference how a specific package, SQL script, or measure was created, check the **[`SOLUTION_GUIDE.md`](file:///c:/Users/menna/Desktop/Wahba/BI%20Projects/Project%201/SOLUTION_GUIDE.md)** in this folder for the complete reference implementation.
