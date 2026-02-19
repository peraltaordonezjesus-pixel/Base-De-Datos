use escuela 
go 
/*
With cre CTE (Common Table Expressions), estas tablas existen solo durante la ejcucion de la sentencica,
a diferencia de las views que se quedan permanentemente en la base de datos
Usamos with cuando necesitamos recursividad, caundo necesitamos reutilizar un soubconjunto varias veces y para
hacer consultas mas legibles 
*/
with R as (
	select distinct A.boleta, A.clave
	from Escuela.Cursa as A
	JOIN Escuela.Imparte AS C
	ON C.clave = A.clave
	WHERE C.numEmpleado = 'P0000001'
	AND A.calif >= 6
),

S as (
	SELECT DISTINCT clave
	FROM escuela.Imparte
	WHERE numEmpleado = 'P0000001'
),

RXS as (
	SELECT a.boleta, s.clave
    FROM (SELECT DISTINCT boleta FROM R) a
    CROSS JOIN S
),

RXS_R as (
   SELECT tc.boleta, tc.clave
    FROM RXS tc
	where not exists (select 1
	                  from R
					  where tc.boleta = r.boleta 
					  AND tc.clave = r.clave)
)
SELECT boleta
FROM R
EXCEPT
SELECT boleta 
FROM RXS_R