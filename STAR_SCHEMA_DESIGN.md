# Star Schema Architecture: EFG_DW

## 1. Schema Overview

The Data Warehouse implements a **Star Schema** centered around the transactional sales grain (1 row per order line), supported by 5 dimensions.

```mermaid
erDiagram
    Dim_Date ||--o{ Fact_Sales : "has (DateSK)"
    Dim_Customer ||--o{ Fact_Sales : "placed by (CustomerSK)"
    Dim_Product ||--o{ Fact_Sales : "contains (ProductSK)"
    Dim_Channel ||--o{ Fact_Sales : "ordered via (ChannelSK)"
    Dim_Region ||--o{ Dim_Customer : "grouped by (City)"

    Dim_Date {
        int DateSK PK "YYYYMMDD"
        date FullDate UK
        int Day
        nvarchar DayName
        int Month
        nvarchar MonthName
        int Quarter
        nvarchar QuarterName
        int Year
        bit IsWeekend
    }

    Dim_Customer {
        int CustomerSK PK "IDENTITY(1,1)"
        nvarchar CustomerID UK "Natural Key"
        nvarchar City
        nvarchar Region
        nvarchar AgeGroup
        date SignupDate
        datetime CreatedDate
        datetime ModifiedDate
    }

    Dim_Product {
        int ProductSK PK "IDENTITY(1,1)"
        nvarchar ProductID UK "Natural Key"
        nvarchar Category
        decimal ListPrice
        decimal Cost
        decimal Margin
        decimal MarginPct
        datetime CreatedDate
        datetime ModifiedDate
    }

    Dim_Channel {
        int ChannelSK PK "IDENTITY(1,1)"
        nvarchar ChannelName UK
    }

    Dim_Region {
        int RegionSK PK "IDENTITY(1,1)"
        nvarchar City UK
        nvarchar Region
    }

    Fact_Sales {
        bigint SalesSK PK "IDENTITY(1,1)"
        nvarchar OrderID "Degenerate Key"
        int DateSK FK
        int CustomerSK FK
        int ProductSK FK
        int ChannelSK FK
        int Quantity "Additive"
        decimal ListPrice "Semi-additive snapshot"
        decimal Cost "Semi-additive snapshot"
        decimal TotalSales "Additive: Qty * ListPrice"
        decimal TotalCost "Additive: Qty * Cost"
        decimal GrossProfit "Additive: TotalSales - TotalCost"
        datetime LoadedDate
    }
```

---

## 2. Table Specifications

### A. Fact Table: `dbo.Fact_Sales`
* **Grain:** 1 record per order line item.
* **Foreign Keys:**
  * `DateSK` $\rightarrow$ `dbo.Dim_Date(DateSK)`
  * `CustomerSK` $\rightarrow$ `dbo.Dim_Customer(CustomerSK)`
  * `ProductSK` $\rightarrow$ `dbo.Dim_Product(ProductSK)`
  * `ChannelSK` $\rightarrow$ `dbo.Dim_Channel(ChannelSK)`
* **Measures:**
  * `Quantity`: Units sold.
  * `ListPrice`: Unit selling price at time of sale.
  * `Cost`: Unit cost at time of sale.
  * `TotalSales`: `Quantity * ListPrice`.
  * `TotalCost`: `Quantity * Cost`.
  * `GrossProfit`: `TotalSales - TotalCost`.

### B. Staging Layer: `stg.*`
* `stg.Customers`: Raw landing for `customers.csv`.
* `stg.Products`: Raw landing for `products.csv`.
* `stg.Orders`: Raw landing for `orders.csv`.
