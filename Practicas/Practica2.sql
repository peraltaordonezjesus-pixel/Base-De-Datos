----use AdventureWorks2022
----go

------=========================================
------=============Consulta1===================
------=========================================

----create nonclustered index nc_orderdate_SalesOrderHeader 
----on Sales.SalesOrderHeader(orderDate) 

----create nonclustered index nc_listprice_Product 
----on Production.Product(ListPrice)

----CREATE NONCLUSTERED INDEX nc_product_SalesOrderDetail
----ON Sales.SalesOrderDetail(ProductID, SalesOrderID)
----INCLUDE(OrderQty);

----set statistics IO on;
----set statistics time on;

----SELECT 
----	p.Name AS Producto, 
----	sod.OrderQty, soh.OrderDate, 
----	persona.FirstName + ' ' + persona.LastName AS Cliente
----FROM Production.Product p
----JOIN Sales.SalesOrderDetail sod 
----	ON p.ProductID = sod.ProductID
----JOIN Sales.SalesOrderHeader soh 
----	ON sod.SalesOrderID = soh.SalesOrderID
----JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID
----LEFT JOIN Person.Person persona on c.PersonID = persona.BusinessEntityID
----WHERE soh.OrderDate BETWEEN '2014-01-01' AND '2014-12-31' 
----AND p.ListPrice > 1000;

----set statistics IO off;
----set statistics time off;


------=========================================
------=============Consulta2===================
------=========================================

--create nonclustered index nc_EndDate_EmployeeDepartmentHistory
--on HumanResources.EmployeeDepartmentHistory(EndDate)

--create nonclustered index nc_BusinessEntityID_EmployeePayHistory
--on HumanResources.EmployeePayHistory(BusinessEntityID)

--create nonclustered index nc_EmployeeDepartmentHistory
--on HumanResources.EmployeeDepartmentHistory(BusinessEntityID, EndDate)
--include(DepartmentID)

--set statistics io on;
--set statistics time on;

--SELECT e.NationalIDNumber, p.FirstName, p.LastName, edh.DepartmentID,
--       (SELECT AVG(rh.Rate) FROM HumanResources.EmployeePayHistory rh 
--        WHERE rh.BusinessEntityID = e.BusinessEntityID) as PromedioSalario
--FROM HumanResources.Employee e
--JOIN Person.Person p ON e.BusinessEntityID = p.BusinessEntityID
--JOIN HumanResources.EmployeeDepartmentHistory edh ON e.BusinessEntityID = edh.BusinessEntityID
--WHERE edh.EndDate IS NULL;	

--set statistics io off;
--set statistics time off;


set statistics io on;
set statistics time on;

CREATE NONCLUSTERED INDEX idx_Product_ListPrice
ON Production.Product(ListPrice)
INCLUDE(ProductSubcategoryID, Name);

CREATE NONCLUSTERED INDEX idx_ProductSubcategory
ON Production.ProductSubcategory(ProductSubcategoryID, ProductCategoryID);

CREATE NONCLUSTERED INDEX idx_SalesOrderDetail_ProductID
ON Sales.SalesOrderDetail(ProductID)

SELECT sod.SalesOrderID, p.ProductID, p.Name
FROM Sales.SalesOrderDetail sod
JOIN Production.Product p 
    ON sod.ProductID = p.ProductID
JOIN Production.ProductSubcategory ps 
    ON p.ProductSubcategoryID = ps.ProductSubcategoryID
JOIN Production.ProductCategory pc 
    ON ps.ProductCategoryID = pc.ProductCategoryID
WHERE pc.ProductCategoryID IN (1, 2, 3)
   OR p.ListPrice > 500;




   set statistics io on;
set statistics time on;

select 
    p.ProductID,
    p.Name,
    v.TotalVendido
from (
    select 
        sod.ProductID,
        sum(sod.OrderQty) as TotalVendido
    from Sales.SalesOrderHeader soh
    inner join Sales.SalesOrderDetail sod
        on soh.SalesOrderID = sod.SalesOrderID
    where soh.OrderDate >= '20140101'
      and soh.OrderDate <  '20150101'
    group by sod.ProductID
    having sum(sod.OrderQty) > 100

) as v
inner join Production.Product p
    on p.ProductID = v.ProductID;

set statistics io off;
set statistics time off;

--
--4
SELECT YEAR(soh.OrderDate) AS Año, MONTH(soh.OrderDate) AS Mes,
       COUNT(*) AS TotalPedidos, SUM(sod.LineTotal) AS TotalVentas
FROM Sales.SalesOrderHeader soh
JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
GROUP BY YEAR(soh.OrderDate), MONTH(soh.OrderDate);
--
-- Columna calculada 
ALTER TABLE Sales.SalesOrderHeader
ADD OrderYearMonth AS (YEAR(OrderDate)*100 + MONTH(OrderDate)); 
-- Índices 
CREATE NONCLUSTERED INDEX IX_SOH_YearMonth 
ON Sales.SalesOrderHeader(OrderYearMonth) 
INCLUDE(SalesOrderID);
CREATE NONCLUSTERED INDEX IX_SOD_SalesOrderID 
ON Sales.SalesOrderDetail(SalesOrderID) 
INCLUDE(LineTotal);
-- Consulta optimizada 
SELECT 
soh.OrderYearMonth, COUNT(*) AS TotalPedidos,
SUM(sod.LineTotal) AS TotalVentas 
FROM Sales.SalesOrderHeader soh JOIN Sales.SalesOrderDetail sod 
ON soh.SalesOrderID = sod.SalesOrderID GROUP BY soh.OrderYearMonth;

--------------------------------------------------------------}
--6 


SELECT c.CustomerID, c.Name, COUNT(*) AS TotalPedidos
FROM Sales.Customer c
JOIN Sales.SalesOrderHeader soh 
    ON c.CustomerID = soh.CustomerID
WHERE UPPER(c.Name) LIKE 'A%'
GROUP BY c.CustomerID, c.Name;
-- la consulta esta mal ya que En AdventureWorks, Sales.Customer no tiene Name lo cual provoca error

--correccion 
IF OBJECT_ID('Sales.Customer_WithName', 'V') IS NOT NULL
    DROP VIEW Sales.Customer_WithName;
GO

CREATE VIEW Sales.Customer_WithName AS
SELECT 
    c.CustomerID,
    ISNULL(p.FirstName + ' ' + p.LastName, s.Name) AS Name
FROM Sales.Customer c
LEFT JOIN Person.Person p 
    ON c.PersonID = p.BusinessEntityID
LEFT JOIN Sales.Store s 
    ON c.StoreID = s.BusinessEntityID;
GO
--se ejecuta ahora si la consuta original 
SELECT c.CustomerID, c.Name, COUNT(*) AS TotalPedidos
FROM Sales.Customer_WithName c
JOIN Sales.SalesOrderHeader soh 
    ON c.CustomerID = soh.CustomerID
WHERE UPPER(c.Name) LIKE 'A%'
GROUP BY c.CustomerID, c.Name;

--optimizacion
CREATE NONCLUSTERED INDEX IX_CustomerWithName_Name
ON Sales.Customer_WithName(Name);

SELECT c.CustomerID, c.Name, COUNT(*) AS TotalPedidos
FROM Sales.Customer_WithName c
JOIN Sales.SalesOrderHeader soh 
    ON c.CustomerID = soh.CustomerID
WHERE c.Name LIKE 'A%'
GROUP BY c.CustomerID, c.Name;

--------------------------------------------------------------------
--7
SELECT TOP 100 
    sod.SalesOrderDetailID, 
    sod.OrderQty, 
    sod.UnitPrice, 
    soh.OrderDate
FROM Sales.SalesOrderDetail sod
JOIN Sales.SalesOrderHeader soh 
    ON sod.SalesOrderID = soh.SalesOrderID
ORDER BY 
    soh.ShipDate DESC, 
    sod.OrderQty DESC, 
    sod.UnitPrice DESC;
----
-- Índices
CREATE NONCLUSTERED INDEX IX_SOH_ShipDate
ON Sales.SalesOrderHeader(ShipDate DESC)
INCLUDE(SalesOrderID, OrderDate);
CREATE NONCLUSTERED INDEX IX_SOD_Order
ON Sales.SalesOrderDetail(SalesOrderID, OrderQty DESC, UnitPrice DESC)
INCLUDE(SalesOrderDetailID);
-- Consulta (sin cambios)
SELECT TOP 100 
    sod.SalesOrderDetailID, 
    sod.OrderQty, 
    sod.UnitPrice, 
    soh.OrderDate
FROM Sales.SalesOrderDetail sod
JOIN Sales.SalesOrderHeader soh 
    ON sod.SalesOrderID = soh.SalesOrderID
ORDER BY 
    soh.ShipDate DESC, 
    sod.OrderQty DESC, 
    sod.UnitPrice DESC;

-----------------------------------------------------------------------------------


--CONSULTA NUMERO 9

set statistics io on;
set statistics time on;

select 
    p.ProductID,
    p.Name,
    isnull(v.VecesVendido, 0) as VecesVendido,
    isnull(v.Ingresos, 0) as Ingresos
from Production.Product p
inner join Production.ProductSubcategory psc
    on p.ProductSubcategoryID = psc.ProductSubcategoryID
left join (
    select 
        sod.ProductID,
        count(*) as VecesVendido,
        sum(sod.OrderQty * sod.UnitPrice) as Ingresos
    from Sales.SalesOrderDetail sod
    group by sod.ProductID
) as v
    on p.ProductID = v.ProductID
where psc.ProductCategoryID = 3;

set statistics io on;
set statistics time on;



--CONSULTA 10


set statistics io on;
set statistics time on;

select 
    pp.FirstName + ' ' + pp.LastName as Cliente,
    p.Name as Producto,
    sum(sod.OrderQty) as Cantidad,
    sum(sod.LineTotal) as Total,
    avg(datediff(day, soh.OrderDate, soh.ShipDate) * 1.0) as DiasEnvioPromedio
from Sales.SalesOrderHeader soh
inner join Sales.Customer c
    on soh.CustomerID = c.CustomerID
inner join Person.Person pp
    on c.PersonID = pp.BusinessEntityID
inner join Sales.SalesOrderDetail sod
    on soh.SalesOrderID = sod.SalesOrderID
inner join Production.Product p
    on sod.ProductID = p.ProductID
where soh.OrderDate >= '20130401'
  and soh.OrderDate <  '20130701'
  and soh.ShipDate is not null
  and soh.ShipDate > dateadd(day, 5, soh.OrderDate)
  and sod.LineTotal > 1000
group by 
    pp.FirstName,
    pp.LastName,
    p.Name
order by Total desc;

set statistics io off;
set statistics time off;