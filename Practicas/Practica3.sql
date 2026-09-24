use covidHistorico2
GO
 
/* años existentes */
SELECT 
    YEAR(TRY_CONVERT(DATE, REPLACE(FECHA_INGRESO,'"',''))) AS Anio,
    COUNT(*) AS Total
FROM datoscovid
WHERE TRY_CONVERT(DATE, REPLACE(FECHA_INGRESO,'"','')) IS NOT NULL
GROUP BY YEAR(TRY_CONVERT(DATE, REPLACE(FECHA_INGRESO,'"','')))
ORDER BY Anio;
GO
 
/* Eliminar objetos si ya existen */
IF OBJECT_ID('covid_particionado', 'U') IS NOT NULL
    DROP TABLE covid_particionado;
GO
 
IF EXISTS (SELECT * FROM sys.partition_schemes WHERE name = 'ps_anio_fg')
    DROP PARTITION SCHEME ps_anio_fg;
GO
 
IF EXISTS (SELECT * FROM sys.partition_functions WHERE name = 'pf_anio')
    DROP PARTITION FUNCTION pf_anio;
GO
 
/* Crear filegroups si es que no existen */
IF NOT EXISTS (SELECT * FROM sys.filegroups WHERE name = 'FG_ANTES_2020')
    ALTER DATABASE CovidHistorico2 ADD FILEGROUP FG_ANTES_2020;
GO
 
IF NOT EXISTS (SELECT * FROM sys.filegroups WHERE name = 'FG_2020')
    ALTER DATABASE CovidHistorico2 ADD FILEGROUP FG_2020;
GO
 
IF NOT EXISTS (SELECT * FROM sys.filegroups WHERE name = 'FG_2021')
    ALTER DATABASE CovidHistorico2 ADD FILEGROUP FG_2021;
GO
 
IF NOT EXISTS (SELECT * FROM sys.filegroups WHERE name = 'FG_2022_MAS')
    ALTER DATABASE CovidHistorico2 ADD FILEGROUP FG_2022_MAS;
GO
 
/* Crear archivos .ndf si no existen */
IF NOT EXISTS (SELECT * FROM sys.database_files WHERE name = 'FG_ANTES_2020_dat')
BEGIN
    ALTER DATABASE CovidHistorico2 
    ADD FILE (
        NAME = FG_ANTES_2020_dat, 
        FILENAME = 'C:\Data\FG_ANTES_2020.ndf'
    )
    TO FILEGROUP FG_ANTES_2020;
END
GO
 
IF NOT EXISTS (SELECT * FROM sys.database_files WHERE name = 'FG_2020_dat')
BEGIN
    ALTER DATABASE CovidHistorico2
    ADD FILE (
        NAME = FG_2020_dat, 
        FILENAME = 'C:\Data\FG_2020.ndf'
    )
    TO FILEGROUP FG_2020;
END
GO
 
IF NOT EXISTS (SELECT * FROM sys.database_files WHERE name = 'FG_2021_dat')
BEGIN
    ALTER DATABASE CovidHistorico2
    ADD FILE (
        NAME = FG_2021_dat, 
        FILENAME = 'C:\Data\FG_2021.ndf'
    )
    TO FILEGROUP FG_2021;
END
GO
 
IF NOT EXISTS (SELECT * FROM sys.database_files WHERE name = 'FG_2022_MAS_dat')
BEGIN
    ALTER DATABASE CovidHistorico2
    ADD FILE (
        NAME = FG_2022_MAS_dat, 
        FILENAME = 'C:\Data\FG_2022_MAS.ndf'
    )
    TO FILEGROUP FG_2022_MAS;
END
GO
 
/* Crear función de particionamiento */
CREATE PARTITION FUNCTION pf_anio (DATE)
AS RANGE RIGHT FOR VALUES 
(
    '2020-01-01', 
    '2021-01-01', 
    '2022-01-01'
);
GO
 
/* Crear esquema de particionamiento con filegroups */
CREATE PARTITION SCHEME ps_anio_fg
AS PARTITION pf_anio
TO (
    FG_ANTES_2020,
    FG_2020,
    FG_2021,
    FG_2022_MAS
);
GO
 
/* Creacion de la tabla particionada */
CREATE TABLE covid_particionado (
    Id INT IDENTITY(1,1) NOT NULL,
    FECHA_INGRESO DATE NOT NULL,
    ENTIDAD_RES VARCHAR(50),
    EDAD INT,
    CONSTRAINT PK_covid_particionado
        PRIMARY KEY CLUSTERED (FECHA_INGRESO, Id)
)
ON ps_anio_fg(FECHA_INGRESO);
GO
 
/* Insertar datos */
INSERT INTO covid_particionado (FECHA_INGRESO, ENTIDAD_RES, EDAD)
SELECT 
    TRY_CONVERT(DATE, REPLACE(FECHA_INGRESO,'"','')),
    REPLACE(ENTIDAD_RES,'"',''),
    TRY_CONVERT(INT, REPLACE(EDAD,'"',''))
FROM datoscovid
WHERE TRY_CONVERT(DATE, REPLACE(FECHA_INGRESO,'"','')) IS NOT NULL;
GO
 
/* Ver límites de partición */
SELECT 
    pf.name AS FuncionParticion,
    prv.value AS Limite
FROM sys.partition_functions pf
JOIN sys.partition_range_values prv 
    ON pf.function_id = prv.function_id
WHERE pf.name = 'pf_anio';
GO
 
/* Ver filas por partición */
SELECT 
    p.partition_number AS NumeroParticion,
    p.rows AS Filas
FROM sys.partitions p
WHERE p.object_id = OBJECT_ID('covid_particionado')
AND p.index_id = 1;
GO
 
/* Ver detalle de particiones */
SELECT 
    t.name AS Tabla,
    i.name AS Indice,
    p.partition_number AS NumeroParticion,
    p.rows AS Filas
FROM sys.tables t
JOIN sys.indexes i 
    ON t.object_id = i.object_id
JOIN sys.partitions p 
    ON i.object_id = p.object_id 
    AND i.index_id = p.index_id
WHERE t.name = 'covid_particionado';
GO
 
/* Consulta de prueba */
SET STATISTICS IO ON;
 
SELECT *
FROM covid_particionado
WHERE FECHA_INGRESO >= '2020-01-01'
  AND FECHA_INGRESO < '2021-01-01';
 
SET STATISTICS IO OFF;
GO


/*INTEGRANTES DEL EQUIPO 
    VALENCIA CEDEÑO MARCOS GAEL
    PERALT ORDOÑEZ JESUS
    VARGAS CLEMENTE LEONEL 
le envio la parte de particionamiento de tablas en sql con la base de datos covidHistorico2*/