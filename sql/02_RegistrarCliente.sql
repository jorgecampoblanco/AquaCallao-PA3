-- PA3 - AquaCallao | 02: Registrar cliente (beneficiario)
-- Autor: Andy Alexandre Lescano Espino
-- Sesion 9: procedimiento almacenado de mantenimiento con parametros de entrada,
--           parametro de salida (OUTPUT) y valor de retorno (RETURN).
-- Requisito: haber ejecutado 01_CrearTablas.sql en una base recien inicializada.
--
-- Contrato cliente/servidor
--   Entrada (cliente -> servidor): @Nombre, @Documento, @Sector
--   Salida  (servidor -> cliente): @ClienteID OUTPUT = identificador del cliente creado
--   RETURN  (servidor -> cliente): codigo de estado de la operacion
--       0 = cliente registrado
--       1 = datos invalidos (vacios, documento con caracteres no numericos o fuera de 8-12)
--       2 = documento ya registrado (no se inserta nada)
--   OUTPUT devuelve un DATO (el ID); RETURN devuelve un ESTADO (como termino la operacion).

USE AquaCallao;
GO

CREATE OR ALTER PROCEDURE dbo.usp_RegistrarCliente
    @Nombre    nvarchar(100),
    @Documento varchar(20),      -- mas largo que la columna (12) para validar y no truncar en silencio
    @Sector    nvarchar(60),
    @ClienteID int OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @ClienteID = NULL;       -- si algo falla, el cliente nunca recibe un ID

    -- Normalizar espacios
    SET @Nombre    = LTRIM(RTRIM(@Nombre));
    SET @Documento = LTRIM(RTRIM(@Documento));
    SET @Sector    = LTRIM(RTRIM(@Sector));

    -- Regla 1: datos obligatorios y documento valido (solo digitos, 8 a 12, conserva ceros iniciales)
    IF @Nombre = N'' OR @Nombre IS NULL
       OR @Sector = N'' OR @Sector IS NULL
       OR @Documento IS NULL
       OR LEN(@Documento) NOT BETWEEN 8 AND 12
       OR @Documento LIKE '%[^0-9]%'
    BEGIN
        RAISERROR(N'Datos invalidos: nombre, sector y documento (8 a 12 digitos) son obligatorios.', 16, 1);
        RETURN 1;
    END

    -- Regla 2: el documento no puede repetirse
    IF EXISTS (SELECT 1 FROM dbo.Cliente WHERE Documento = @Documento)
    BEGIN
        RAISERROR(N'El documento %s ya esta registrado. No se inserto el cliente.', 16, 1, @Documento);
        RETURN 2;
    END

    BEGIN TRY
        INSERT INTO dbo.Cliente (Nombre, Documento, Sector, Activo)
        VALUES (@Nombre, @Documento, @Sector, 1);   -- todo beneficiario nuevo nace activo

        SET @ClienteID = CAST(SCOPE_IDENTITY() AS int);
        RETURN 0;
    END TRY
    BEGIN CATCH
        -- Respaldo: si otra sesion registro el mismo documento entre la validacion y el INSERT,
        -- la restriccion UQ_Cliente_Documento lo rechaza (errores 2627 / 2601).
        IF ERROR_NUMBER() IN (2627, 2601)
        BEGIN
            RAISERROR(N'El documento %s ya esta registrado. No se inserto el cliente.', 16, 1, @Documento);
            RETURN 2;
        END;
        THROW;   -- cualquier otro error se devuelve tal cual al cliente
    END CATCH
END;
GO

/* =====================================================================
   PRUEBA P1 - Alta de cliente (ejecutar sobre base recien inicializada)
   ===================================================================== */

-- Estado ANTES
SELECT 'ANTES' AS Momento, COUNT(*) AS FilasCliente FROM dbo.Cliente;
GO

-- P1-A: cliente de otro sector -> RETURN 0 y se devuelve el ID por OUTPUT
DECLARE @id int, @ret int;
EXEC @ret = dbo.usp_RegistrarCliente
     @Nombre    = N'Beneficiario Mi Peru 01',
     @Documento = '04567890',
     @Sector    = N'Mi Perú',
     @ClienteID = @id OUTPUT;
SELECT 'P1-A alta' AS Caso, @ret AS CodigoRetorno, @id AS ClienteID_Devuelto;
SELECT * FROM dbo.Cliente WHERE ClienteID = @id;
GO

-- P1-B: se repite el documento -> error informado, RETURN 2, ID NULL
DECLARE @id int, @ret int;
EXEC @ret = dbo.usp_RegistrarCliente
     @Nombre    = N'Beneficiario Duplicado',
     @Documento = '04567890',
     @Sector    = N'Callao',
     @ClienteID = @id OUTPUT;
SELECT 'P1-B duplicado' AS Caso, @ret AS CodigoRetorno, @id AS ClienteID_Devuelto;
GO

-- P1-C (complementaria): documento con letras -> RETURN 1, no se inserta
DECLARE @id int, @ret int;
EXEC @ret = dbo.usp_RegistrarCliente
     @Nombre    = N'Beneficiario Invalido',
     @Documento = 'ABC12345',
     @Sector    = N'Callao',
     @ClienteID = @id OUTPUT;
SELECT 'P1-C invalido' AS Caso, @ret AS CodigoRetorno, @id AS ClienteID_Devuelto;
GO

-- Estado DESPUES: debe haber 2 clientes y UNA sola fila con el documento 04567890
SELECT 'DESPUES' AS Momento, COUNT(*) AS FilasCliente FROM dbo.Cliente;
SELECT Documento, COUNT(*) AS Filas FROM dbo.Cliente WHERE Documento = '04567890' GROUP BY Documento;
SELECT ClienteID, Nombre, Documento, Sector, Activo FROM dbo.Cliente ORDER BY ClienteID;
GO
