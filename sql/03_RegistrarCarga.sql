/* ---------------------------------------------------------------------
   Archivo:       03_RegistrarCarga.sql
   Responsable:   Fernando Álvaro Quispe Trigos
   Propósito:     Definición del procedimiento usp_RegistrarCarga y
                  protocolo de prueba en 3 momentos para evidencia
                  transaccional (COMMIT y ROLLBACK).
   --------------------------------------------------------------------- */
USE AquaCallao;
GO
-- 1. Definición del Procedimiento 
   
-- Definimos 3 valores
CREATE OR ALTER PROCEDURE dbo.usp_RegistrarCarga
    @CisternaID INT,
    @ProductoID INT,
    @Litros     INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Validación preventiva de litros positivos
    IF @Litros <= 0
    BEGIN
        RAISERROR(N'La cantidad de litros a cargar debe ser estrictamente positiva.', 16, 1);
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @CapacidadLitros INT,
                @SaldoActual     INT,
                @Estado          VARCHAR(12);

        -- Bloqueo de fila para evitar condiciones de carrera (Race Conditions)
        SELECT 
            @CapacidadLitros = CapacidadLitros,
            @SaldoActual     = SaldoLitros,
            @Estado          = Estado
        FROM dbo.Cisterna WITH (UPDLOCK, ROWLOCK)
        WHERE CisternaID = @CisternaID;

        -- Validaciones de regla de negocio
        IF @CapacidadLitros IS NULL
        BEGIN
            RAISERROR(N'La cisterna especificada (ID: %d) no existe.', 16, 1, @CisternaID);
        END;

        IF @Estado <> 'Operativa'
        BEGIN
            RAISERROR(N'La cisterna %d no está operativa (Estado actual: %s).', 16, 1, @CisternaID, @Estado);
        END;

        IF NOT EXISTS (SELECT 1 FROM dbo.Producto WHERE ProductoID = @ProductoID AND Activo = 1)
        BEGIN
            RAISERROR(N'El producto especificado (ID: %d) no existe o no está activo.', 16, 1, @ProductoID);
        END;

        -- Verificación de capacidad física
        IF (@SaldoActual + @Litros) > @CapacidadLitros
        BEGIN
            DECLARE @Disponible INT = @CapacidadLitros - @SaldoActual;
            RAISERROR(
                N'Capacidad insuficiente. Saldo actual: %d L, Carga intentada: %d L, Límite: %d L (Disponible: %d L).',
                16, 1, @SaldoActual, @Litros, @CapacidadLitros, @Disponible
            );
        END;

        -- 1. Insertar el movimiento en el historial
        INSERT INTO dbo.CargaAgua (CisternaID, ProductoID, Litros, FechaCarga)
        VALUES (@CisternaID, @ProductoID, @Litros, SYSDATETIME());

        -- 2. Incrementar el saldo disponible
        UPDATE dbo.Cisterna
        SET SaldoLitros = SaldoLitros + @Litros
        WHERE CisternaID = @CisternaID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO

-- 2. Protocolo de Pruebas: 3 Momentos Transaccionales (Caso P2)

PRINT '=====================================================================';
PRINT 'EVIDENCIA TRANSACCIONAL P2 - Fernando Álvaro Quispe Trigos';
PRINT '=====================================================================';


-- MOMENTO 1: Estado inicial tras inicialización de base de datos
-- Esperado: Saldo = 0 L, Total cargas = 0
PRINT '>>> MOMENTO 1: Estado inicial';
SELECT 
    '1. ANTES' AS Momento,
    CisternaID,
    Placa,
    CapacidadLitros,
    SaldoLitros,
    Estado
FROM dbo.Cisterna 
WHERE CisternaID = 1;

SELECT 
    '1. ANTES' AS Momento,
    COUNT(*) AS CantidadCargas,
    ISNULL(SUM(Litros), 0) AS TotalLitrosCargados
FROM dbo.CargaAgua 
WHERE CisternaID = 1;
GO

-- MOMENTO 2: Después de la carga válida de 1 000 L (Éxito de COMMIT)
-- Esperado: Saldo = 1 000 L, Total cargas = 1 (por 1 000 L)

PRINT '>>> Ejecutando Carga Válida (1 000 L)...';
EXEC dbo.usp_RegistrarCarga 
    @CisternaID = 1, 
    @ProductoID = 1, 
    @Litros     = 1000;

PRINT '>>> MOMENTO 2: Verificación post-COMMIT (Carga válida)';

SELECT 
    '2. TRAS COMMIT (1 000 L)' AS Momento,
    CisternaID,
    Placa,
    CapacidadLitros,
    SaldoLitros,
    Estado
FROM dbo.Cisterna 
WHERE CisternaID = 1;

SELECT 
    '2. TRAS COMMIT (1 000 L)' AS Momento,
    CargaID,
    CisternaID,
    ProductoID,
    Litros,
    FechaCarga
FROM dbo.CargaAgua 
WHERE CisternaID = 1;
GO

-- MOMENTO 3: Tras intentar cargar 1 100 L adicionales (Efecto de ROLLBACK)
-- Regla: 1 000 L (actual) + 1 100 L (intento) = 2 100 L > 2 000 L (Capacidad)
-- Esperado: Error de capacidad. Se mantiene Saldo = 1 000 L y 1 sola carga.
   
PRINT '>>> Intentando Carga Inválida (1 100 L adicionales)...';
BEGIN TRY
    EXEC dbo.usp_RegistrarCarga 
        @CisternaID = 1, 
        @ProductoID = 1, 
        @Litros     = 1100;
END TRY
BEGIN CATCH
    PRINT CONCAT('Excepción controlada: ', ERROR_MESSAGE());
END CATCH;

PRINT '>>> MOMENTO 3: Verificación post-ROLLBACK (Protección de estado)';

SELECT 
    '3. TRAS ROLLBACK (Exceso)' AS Momento,
    CisternaID,
    Placa,
    CapacidadLitros,
    SaldoLitros,
    Estado
FROM dbo.Cisterna 
WHERE CisternaID = 1;

SELECT 
    '3. TRAS ROLLBACK (Exceso)' AS Momento,
    CargaID,
    CisternaID,
    ProductoID,
    Litros,
    FechaCarga
FROM dbo.CargaAgua 
WHERE CisternaID = 1;
GO
