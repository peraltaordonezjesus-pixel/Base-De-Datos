--PRACTICA 2 BDD
--Peralta Ordoñez Jesus
--Valencia Cedeño Marcos Gael
--Vargas Clemente Leonel Zahid

use AdventureWorks2022
go

--=========================================
--=============Consulta1===================
--=========================================

----create nonclustered index nc_orderdate_SalesOrderHeader 
----on Sales.SalesOrderHeader(orderDate) 

----create nonclustered index nc_listprice_Product 
----on Production.Product(ListPrice)

----CREATE NONCLUSTERED INDEX nc_product_SalesOrderDetail
----ON Sales.SalesOrderDetail(ProductID, SalesOrderID)
----INCLUDE(OrderQty);

--set statistics IO on;
--set statistics time on;

--SELECT 
--	p.Name AS Producto, 
--	sod.OrderQty, soh.OrderDate, 
--	persona.FirstName + ' ' + persona.LastName AS Cliente
--FROM Production.Product p
--JOIN Sales.SalesOrderDetail sod 
--	ON p.ProductID = sod.ProductID
--JOIN Sales.SalesOrderHeader soh 
--	ON sod.SalesOrderID = soh.SalesOrderID
--JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID
--LEFT JOIN Person.Person persona on c.PersonID = persona.BusinessEntityID
--WHERE soh.OrderDate BETWEEN '2014-01-01' AND '2014-12-31' 
--AND p.ListPrice > 1000;

--set statistics IO off;
--set statistics time off;


--=========================================
--=============Consulta2===================
--=========================================

create nonclustered index nc_EndDate_EmployeeDepartmentHistory
on HumanResources.EmployeeDepartmentHistory(EndDate)

create nonclustered index nc_BusinessEntityID_EmployeePayHistory
on HumanResources.EmployeePayHistory(BusinessEntityID)

create nonclustered index nc_EmployeeDepartmentHistory
on HumanResources.EmployeeDepartmentHistory(BusinessEntityID, EndDate)
include(DepartmentID)

set statistics io on;
set statistics time on;

SELECT e.NationalIDNumber, p.FirstName, p.LastName, edh.DepartmentID,
       (SELECT AVG(rh.Rate) FROM HumanResources.EmployeePayHistory rh 
        WHERE rh.BusinessEntityID = e.BusinessEntityID) as PromedioSalario
FROM HumanResources.Employee e
JOIN Person.Person p ON e.BusinessEntityID = p.BusinessEntityID
JOIN HumanResources.EmployeeDepartmentHistory edh ON e.BusinessEntityID = edh.BusinessEntityID
WHERE edh.EndDate IS NULL;	

set statistics io off;
set statistics time off;

--=========================================
--=============Consulta4===================
--=========================================
SELECT YEAR(soh.OrderDate) AS Año, MONTH(soh.OrderDate) AS Mes,
       COUNT(*) AS TotalPedidos, SUM(sod.LineTotal) AS TotalVentas
FROM Sales.SalesOrderHeader soh
JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
GROUP BY YEAR(soh.OrderDate), MONTH(soh.OrderDate);

--Problema detectado
-- Funciones sobre columna indexada
YEAR(soh.OrderDate)
MONTH(soh.OrderDate)

--Agrupar por rango de fechas
--Reescribe usando una fecha truncada al mes:

SELECT 
    DATEFROMPARTS(YEAR(soh.OrderDate), MONTH(soh.OrderDate), 1) AS FechaMes,
    COUNT(*) AS TotalPedidos,
    SUM(sod.LineTotal) AS TotalVentas
FROM Sales.SalesOrderHeader soh
JOIN Sales.SalesOrderDetail sod 
    ON soh.SalesOrderID = sod.SalesOrderID
GROUP BY 
    DATEFROMPARTS(YEAR(soh.OrderDate), MONTH(soh.OrderDate), 1);



--=========================================
--=============Consulta8===================
--=========================================
/* ============================================================
   CONSULTA OPTIMIZADA: PRODUCTOS MÁS VENDIDOS (>100 unidades)
   ============================================================

   OBJETIVO:
   Obtener los productos que han vendido más de 100 unidades
   en el año 2014, mostrando su ID, nombre y total vendido.

   PROBLEMA DE LA CONSULTA ORIGINAL:
   - Uso de subconsulta con IN (menos eficiente)
   - Doble procesamiento de datos
   - No se aprovechaban bien los índices
   - Posible error al usar SUM sin JOIN en el SELECT principal

   SOLUCIÓN:
   - Primero se agrupan las ventas (tabla derivada)
   - Después se hace JOIN con Product
   - Se reduce el número de registros antes del JOIN final

   BENEFICIO:
   - Menor costo en el plan de ejecución
   - Menos lecturas (IO)
   - Mejor uso de índices
============================================================ */

select 
    p.ProductID,
    p.Name,
    v.TotalVendido
from (

    /* ============================================
       SUBCONSULTA: AGRUPACIÓN DE VENTAS
       ============================================

       Aquí se hace todo el trabajo pesado:
       - Se unen las órdenes con sus detalles
       - Se filtran solo las del año 2014
       - Se agrupa por producto
       - Se calcula el total vendido
       - Se filtran productos con más de 100 unidades
    */

    select 
        sod.ProductID,
        sum(sod.OrderQty) as TotalVendido
    from Sales.SalesOrderHeader soh

    /* JOIN para relacionar encabezado con detalle */
    inner join Sales.SalesOrderDetail sod
        on soh.SalesOrderID = sod.SalesOrderID

    /* FILTRO SARGABLE (mejor para índices) */
    where soh.OrderDate >= '20140101'
      and soh.OrderDate <  '20150101'

    /* AGRUPACIÓN POR PRODUCTO */
    group by sod.ProductID

    /* FILTRO DE AGREGACIÓN */
    having sum(sod.OrderQty) > 100

) as v

/* ============================================
   JOIN FINAL CON PRODUCTOS
   ============================================

   Aquí solo se traen los nombres de productos
   que ya cumplieron la condición anterior.
*/

inner join Production.Product p
    on p.ProductID = v.ProductID;

--=========================================
--=============Consulta6===================
--=========================================
-- 6
SELECT c.CustomerID, c.Name, COUNT(*) AS TotalPedidos
FROM Sales.Customer c
JOIN Sales.SalesOrderHeader soh ON c.CustomerID = soh.CustomerID
WHERE UPPER(c.Name) LIKE 'A%'
GROUP BY c.CustomerID, c.Name;

-- Quitar UPPER()
SELECT c.CustomerID, c.Name, COUNT(*) AS TotalPedidos
FROM Sales.Customer c
JOIN Sales.SalesOrderHeader soh 
    ON c.CustomerID = soh.CustomerID
WHERE c.Name LIKE 'A%'
GROUP BY c.CustomerID, c.Name;





/* ============================================================
   CONSULTA 9 OPTIMIZADA
   ============================================================

   OBJETIVO:
   Mostrar los productos de la categoría 3 junto con:
   - ProductID
   - Nombre
   - Veces que se ha vendido
   - Ingresos generados

   MEJORA REALIZADA:
   En lugar de usar dos subconsultas correlacionadas sobre
   Sales.SalesOrderDetail, se hace una sola agregación.
   Así se evita recorrer la misma tabla varias veces.

   BENEFICIO:
   - Menor costo en el plan de ejecución
   - Menos lecturas lógicas
   - Menor tiempo de procesamiento
   - Consulta más limpia y más fácil de entender
============================================================ */

/* Activar estadísticas para revisar rendimiento */
set statistics io on;
set statistics time on;

select 
    p.ProductID,
    p.Name,
    isnull(v.VecesVendido, 0) as VecesVendido,
    isnull(v.Ingresos, 0) as Ingresos
from Production.Product p

/* Join para identificar solo productos de la categoría 3 */
inner join Production.ProductSubcategory psc
    on p.ProductSubcategoryID = psc.ProductSubcategoryID

/* 
   Tabla derivada:
   Aquí se hace una sola lectura de SalesOrderDetail
   para calcular tanto el conteo como la suma de ingresos
*/
left join (
    select 
        sod.ProductID,
        count(*) as VecesVendido,
        sum(sod.OrderQty * sod.UnitPrice) as Ingresos
    from Sales.SalesOrderDetail sod
    group by sod.ProductID
) as v
    on p.ProductID = v.ProductID

/* Filtro de categoría */
where psc.ProductCategoryID = 3;

/* Desactivar estadísticas */
set statistics io on;
set statistics time on;