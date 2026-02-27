use AdventureWorks2022
/*CONSULTAS RAPIDAS*/
select * from Sales.SalesOrderHeader
select * from Sales.SalesOrderDetail
select * from Production.Product
select * from HumanResources.Employee
select * from Person.Person





/*CONSULTA 1*/
USE AdventureWorks2022
GO

SELECT 
    p.Name,
    T.Cant,
    per.FirstName + ' ' + per.LastName AS NombreCliente
FROM Production.Product p
JOIN (
        SELECT TOP 10 sod.ProductID,
               SUM(sod.OrderQty) AS Cant
        FROM Sales.SalesOrderDetail sod
        JOIN Sales.SalesOrderHeader soh
            ON sod.SalesOrderID = soh.SalesOrderID
        WHERE YEAR(soh.OrderDate) = 2014
        GROUP BY sod.ProductID
        ORDER BY Cant DESC
     ) AS T
    ON p.ProductID = T.ProductID
JOIN Sales.SalesOrderDetail sod2
    ON T.ProductID = sod2.ProductID
JOIN Sales.SalesOrderHeader soh2
    ON sod2.SalesOrderID = soh2.SalesOrderID
JOIN Sales.Customer c
    ON soh2.CustomerID = c.CustomerID
JOIN Person.Person per
    ON c.PersonID = per.BusinessEntityID
WHERE YEAR(soh2.OrderDate) = 2014
ORDER BY T.Cant DESC;


------------------------------------------------------------------------
------------------------------------------------------------------------

USE AdventureWorks2022
GO

SELECT 
    p.Name,
    T.Cant,
    per.FirstName + ' ' + per.LastName AS NombreCliente
FROM Production.Product p
JOIN (
        SELECT TOP 10 
               sod.ProductID,
               SUM(sod.OrderQty) AS Cant,
               AVG(sod.UnitPrice) AS Promedio 
        FROM Sales.SalesOrderDetail sod
        JOIN Sales.SalesOrderHeader soh
            ON sod.SalesOrderID = soh.SalesOrderID
        WHERE YEAR(soh.OrderDate) = 2014
        GROUP BY sod.ProductID
        ORDER BY Cant DESC
     ) AS T
    ON p.ProductID = T.ProductID
JOIN Sales.SalesOrderDetail sod2
    ON T.ProductID = sod2.ProductID
JOIN Sales.SalesOrderHeader soh2
    ON sod2.SalesOrderID = soh2.SalesOrderID
JOIN Sales.Customer c
    ON soh2.CustomerID = c.CustomerID
JOIN Person.Person per
    ON c.PersonID = per.BusinessEntityID
WHERE YEAR(soh2.OrderDate) = 2014
  AND p.ListPrice > 1000
ORDER BY T.Cant DESC;
/*===========================================================================================
=============================================================================================*/
/*CONSULTA 2*/
SELECT
Per.FirstName + ' ' + Per.LastName as nombre,
SUMA.SalesPersonID
FROM Person.Person AS Per	
join(
	select SUM(ORDEN.TotalDue) AS CANT, ORDEN.SalesPersonID
	from Sales.SalesOrderHeader as ORDEN
	where ORDEN.TerritoryID = 1 	
	group by ORDEN.SalesPersonID		
) as SUMA
on SUMA.SalesPersonID = Per.BusinessEntityID
WHERE SUMA.CANT > (
	SELECT AVG(CANT) as promedio 
	FROM (
		select SUM(ORDEN.TotalDue) AS CANT, ORDEN.SalesPersonID
		from Sales.SalesOrderHeader as ORDEN
		where ORDEN.TerritoryID = 1 	
		group by ORDEN.SalesPersonID 
	) AS P
);

-------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------
WITH VentasPorEmpleado AS
(
    SELECT 
        ORDEN.SalesPersonID,
        SUM(ORDEN.TotalDue) AS Cant
    FROM Sales.SalesOrderHeader AS ORDEN
    WHERE ORDEN.TerritoryID = 1
    GROUP BY ORDEN.SalesPersonID
)

SELECT 
    Per.FirstName + ' ' + Per.LastName AS Nombre,
    V.SalesPersonID
FROM VentasPorEmpleado V
JOIN Person.Person Per
    ON V.SalesPersonID = Per.BusinessEntityID
WHERE V.Cant > (
    SELECT AVG(Cant)
    FROM VentasPorEmpleado
);
/*===========================================================================================
=============================================================================================*/
/*CONSULTA 3*/

select top (5) 
soh.SalesOrderID,
soh.OrderDate,
soh.TotalDue,
st.Name as territorio
from Sales.SalesOrderHeader as soh
join Sales.SalesTerritory as st on
st.TerritoryID = soh.TerritoryID;

select
st.Name as Territorio,
year(soh.OrderDate) as Anio,
count(distinct soh.SalesOrderID) as Ordenes,
sum(soh.TotalDue) as VentasTotales
from Sales.SalesOrderHeader as soh
join Sales.SalesTerritory as st
on st.TerritoryID = soh.TerritoryID
group by
st.Name,
year(soh.OrderDate);

select
st.Name as Territorio,
year(soh.OrderDate) as Anio,
count(distinct soh.SalesOrderID) as Ordenes,
sum(soh.TotalDue) as VentasTotales
from Sales.SalesOrderHeader as soh
join Sales.SalesTerritory as st
on st.TerritoryID = soh.TerritoryID
group by
st.Name,
year(soh.OrderDate)
having
count(distinct soh.SalesOrderID) > 5
and sum(soh.TotalDue) > 1000000
order by
VentasTotales desc;

/*CONSULTA 3 PUNTO 1 DESVIACION ESTANDAR DE VENTAS*/
select
st.Name as Territorio,
year(soh.OrderDate) as Anio,
count(distinct soh.SalesOrderID) as Ordenes,
sum(soh.TotalDue) as VentasTotales,
stdev(soh.TotalDue) as DesvStdVentas /*aqui el uso de stdev me da cuanto varian las ventas por orden dentro de cada territorio-año*/
from Sales.SalesOrderHeader as soh
join Sales.SalesTerritory as st
on st.TerritoryID = soh.TerritoryID
group by
st.Name,
year(soh.OrderDate)
having
count(distinct soh.SalesOrderID) > 5
and sum(soh.TotalDue) > 1000000
order by
VentasTotales desc;

/*===========================================================================================
=============================================================================================*/
/*CONSULTA 4*/
;with ProductosCategoria as (
select p.ProductID
from Production.Product as p
join Production.ProductSubcategory as ps
on ps.ProductSubcategoryID = p.ProductSubcategoryID
join Production.ProductCategory as pc
on pc.ProductCategoryID = ps.ProductCategoryID
where pc.Name = 'Bikes'
),
ProductosVendidosPorVendedor as (
select distinct
soh.SalesPersonID,
sod.ProductID
from Sales.SalesOrderHeader as soh
join Sales.SalesOrderDetail as sod
on sod.SalesOrderID = soh.SalesOrderID
where soh.SalesPersonID is not null
)
select
sp.BusinessEntityID as SalesPersonID,
pp.FirstName,
pp.LastName
from Sales.SalesPerson as sp
join Person.Person as pp
on pp.BusinessEntityID = sp.BusinessEntityID
where not exists (
-- “No existe” un producto de Bikes que este vendedor NO haya vendido
SELECT 1
FROM ProductosCategoria AS pc
WHERE not exists (
SELECT 1
FROM ProductosVendidosPorVendedor AS pv
WHERE pv.SalesPersonID = sp.BusinessEntityID
and pv.ProductID = pc.ProductID
    )
);
/*CONSULTA NUMERO 4.1*/


with productoscategoria as (
select p.productid
from production.product as p
join production.productsubcategory as ps
on ps.productsubcategoryid = p.productsubcategoryid
join production.productcategory as pc
on pc.productcategoryid = ps.productcategoryid
where pc.productcategoryid = 4 /*clothing*/
),
productosvendidosporvendedor as (
select distinct
soh.salespersonid,
sod.productid
from sales.salesorderheader as soh
join sales.salesorderdetail as sod
on sod.salesorderid = soh.salesorderid
where soh.salespersonid is not null
)
select
sp.businessentityid as salespersonid,
pp.firstname,
pp.lastname
from sales.salesperson as sp
join person.person as pp
on pp.businessentityid = sp.businessentityid
where not exists (
select 1
from productoscategoria as pc
where not exists (
select 1
from productosvendidosporvendedor as pv
where pv.salespersonid = sp.businessentityid
and pv.productid = pc.productid
    )
);

/*CONSULTA 4.2*/

select
pp.businessentityid as salespersonid,
pp.firstname,
pp.lastname,
pc.name as categoria,
count(distinct sod.productid) as productosdistintosvendidos
from sales.salesperson as sp
join person.person as pp
on pp.businessentityid = sp.businessentityid
join sales.salesorderheader as soh
on soh.salespersonid = sp.businessentityid
join sales.salesorderdetail as sod
on sod.salesorderid = soh.salesorderid
join production.product as p
on p.productid = sod.productid
join production.productsubcategory as ps
on ps.productsubcategoryid = p.productsubcategoryid
join production.productcategory as pc
on pc.productcategoryid = ps.productcategoryid
group by
sp.businessentityid,
pp.firstname,
pp.lastname,
pc.name
order by
sp.businessentityid,
pc.name;

/*CONSULTA NUMERO 5*/
    SELECT name, cant
    FROM Production.Product p
    JOIN (
            SELECT TOP 10 productid, SUM(orderqty) cant
            FROM SV_GAEL.AdventureWorks2022.Sales.SalesOrderDetail sod
            GROUP BY productid
            ORDER BY cant DESC
         ) AS T
    ON p.ProductID = T.ProductID

    SELECT soh.SalesOrderID, sod.ProductID, sod.OrderQty, soh.CustomerID
    FROM SV_GAEL.AdventureWorks2022.Sales.SalesOrderHeader soh 
    JOIN SV_GAEL.AdventureWorks2022.Sales.SalesOrderDetail sod
    ON soh.SalesOrderID = sod.SalesOrderID
    WHERE YEAR(OrderDate) = '2014'


    /*SERVIDORES VINCULADOS */

    --===================================================================
    --===================================================================
    --===================================================================
    /*LINKED SERVER JESUS*/
EXEC sp_addlinkedserver 
   @server = 'SV_GAEL', /*Nombre del servidor a asociar*/
   @srvproduct = 'SQLServer', -- opcional
   @provider = 'MSOLEDBSQL19',
   @datasrc = '172.20.10.4',
   @provstr = 'Encrypt=yes;TrustServerCertificate=yes;';

EXEC sp_addlinkedsrvlogin 
   @rmtsrvname = 'SV_GAEL',
   @useself = 'false', -- valor false si se usarán credenciales distintas
   @rmtuser = 'sa', /*Nombre del servidor a asociar*/
   @rmtpassword = '1234';

EXEC sp_testlinkedserver SV_GAEL;


    /*LINKED SERVER GAEL*/
    EXEC sp_addlinkedserver 
   @server = 'SV_JESUS',
   @srvproduct = 'SQLServer', 
   @provider = 'MSOLEDBSQL19',
   @datasrc = '172.20.10.3',
   @provstr = 'Encrypt=yes;TrustServerCertificate=yes;';

EXEC sp_addlinkedsrvlogin 
   @rmtsrvname = 'SV_JESUS',
   @useself = 'false',
   @rmtuser = 'sa',
   @rmtpassword = '6789';

EXEC sp_testlinkedserver SV_JESUS;  

