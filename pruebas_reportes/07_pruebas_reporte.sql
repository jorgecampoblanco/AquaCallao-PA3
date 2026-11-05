USE AquaCallao;
GO

-- Configuracion para ejecutar las pruebas
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET IMPLICIT_TRANSACTIONS OFF;

IF @@TRANCOUNT <> 0
    THROW 50002, 'Ejecute las pruebas en una sesion sin transacciones abiertas.', 1;

BEGIN TRY
    -- Preparar los datos dentro de una transaccion
    BEGIN TRANSACTION;

    DECLARE @ClienteID INT, @ProductoID INT, @CisternaID INT;
    DECLARE @Codigo VARCHAR(8) = LEFT(REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''), 8);
    DECLARE @Sector NVARCHAR(60) = N'Prueba reporte ' + @Codigo;
    DECLARE @SectorVacio NVARCHAR(60) = N'Sin entregas ' + @Codigo;

    -- Registrar cliente, producto y cisterna de prueba
    INSERT INTO dbo.Cliente (Nombre, Documento, Sector, Activo)
    VALUES (N'Cliente de prueba de reporte', 'R' + @Codigo, @Sector, 1);
    SET @ClienteID = CONVERT(INT, SCOPE_IDENTITY());

    INSERT INTO dbo.Producto (Nombre, UnidadMedida, Activo)
    VALUES (N'Agua potable prueba ' + @Codigo, 'L', 1);
    SET @ProductoID = CONVERT(INT, SCOPE_IDENTITY());

    INSERT INTO dbo.Cisterna (Placa, CapacidadLitros, SaldoLitros, Estado)
    VALUES ('R' + @Codigo, 2000, 1000, 'Operativa');
    SET @CisternaID = CONVERT(INT, SCOPE_IDENTITY());

    -- Registrar una carga y dos entregas para comprobar el reporte
    INSERT INTO dbo.CargaAgua (CisternaID, ProductoID, Litros)
    VALUES (@CisternaID, @ProductoID, 1000);

    INSERT INTO dbo.Entrega (ClienteID, CisternaID, ProductoID, Litros)
    VALUES (@ClienteID, @CisternaID, @ProductoID, 300),
           (@ClienteID, @CisternaID, @ProductoID, 500);

    UPDATE dbo.Cisterna SET SaldoLitros = 200 WHERE CisternaID = @CisternaID;

    DECLARE @Resultado TABLE (Sector NVARCHAR(60), TotalEntregas BIGINT, TotalLitros BIGINT);

    -- R01: comprobar que las dos entregas sumen 800 litros
    INSERT INTO @Resultado
    EXEC dbo.usp_ReporteEntregasPorSector @Sector = @Sector;

    IF (SELECT COUNT(*) FROM @Resultado) <> 1
       OR NOT EXISTS (SELECT 1 FROM @Resultado WHERE Sector = @Sector AND TotalEntregas = 2 AND TotalLitros = 800)
        THROW 50003, 'Fallo el reporte del sector con entregas.', 1;

    SELECT N'R01: dos entregas, 800 litros' AS Prueba, * FROM @Resultado;
    DELETE FROM @Resultado;

    -- R02: comprobar que un sector sin entregas devuelva ceros
    INSERT INTO @Resultado
    EXEC dbo.usp_ReporteEntregasPorSector @Sector = @SectorVacio;

    IF (SELECT COUNT(*) FROM @Resultado) <> 1
       OR NOT EXISTS (SELECT 1 FROM @Resultado WHERE TotalEntregas = 0 AND TotalLitros = 0)
        THROW 50004, 'Fallo el reporte del sector sin entregas.', 1;

    SELECT N'R02: sector sin entregas' AS Prueba, * FROM @Resultado;

    -- Deshacer los datos utilizados en las pruebas
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    -- Cancelar la transaccion si ocurre un error
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- R03: comprobar que se rechace un sector con espacios
DECLARE @Rechazado BIT = 0;
BEGIN TRY
    EXEC dbo.usp_ReporteEntregasPorSector @Sector = N'   ';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() <> 50001 THROW;
    SET @Rechazado = 1;
    SELECT N'R03: sector vacio rechazado' AS Prueba, ERROR_MESSAGE() AS Resultado;
END CATCH;
IF @Rechazado = 0 THROW 50005, 'Se acepto un sector vacio.', 1;
GO

-- R04: comprobar que se rechace un sector nulo
DECLARE @Rechazado BIT = 0;
BEGIN TRY
    EXEC dbo.usp_ReporteEntregasPorSector @Sector = NULL;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() <> 50001 THROW;
    SET @Rechazado = 1;
    SELECT N'R04: sector nulo rechazado' AS Prueba, ERROR_MESSAGE() AS Resultado;
END CATCH;
IF @Rechazado = 0 THROW 50006, 'Se acepto un sector nulo.', 1;
GO
