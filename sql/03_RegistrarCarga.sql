/* =====================================================================
   Archivo:       03_RegistrarCarga.sql
   Responsable:   Fernando Álvaro Quispe Trigos
   Propósito:     Registrar el ingreso de agua a una cisterna aumentando
                  el saldo e insertando la carga bajo una transacción
                  explícita, validando operatividad y capacidad física.
   ===================================================================== */
USE AquaCallao;
GO

CREATE OR ALTER PROCEDURE dbo.usp_RegistrarCarga
    @CisternaID INT,
    @ProductoID INT,
    @Litros     INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Validación de parámetro
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

        -- Lectura bloqueante (UPDLOCK, ROWLOCK) para evitar condiciones de carrera concurrentes
        SELECT 
            @CapacidadLitros = CapacidadLitros,
            @SaldoActual     = SaldoLitros,
            @Estado          = Estado
        FROM dbo.Cisterna WITH (UPDLOCK, ROWLOCK)
        WHERE CisternaID = @CisternaID;

        -- 1. Validar existencia de la cisterna
        IF @CapacidadLitros IS NULL
        BEGIN
            RAISERROR(N'La cisterna especificada (ID: %d) no existe.', 16, 1, @CisternaID);
        END;

        -- 2. Validar estado operativo
        IF @Estado <> 'Operativa'
        BEGIN
            RAISERROR(N'La cisterna %d no está operativa (Estado actual: %s).', 16, 1, @CisternaID, @Estado);
        END;

        -- 3. Validar existencia y estado del producto
        IF NOT EXISTS (SELECT 1 FROM dbo.Producto WHERE ProductoID = @ProductoID AND Activo = 1)
        BEGIN
            RAISERROR(N'El producto especificado (ID: %d) no existe o no está activo.', 16, 1, @ProductoID);
        END;

        -- 4. Validar capacidad física disponible
        IF (@SaldoActual + @Litros) > @CapacidadLitros
        BEGIN
            DECLARE @Disponible INT = @CapacidadLitros - @SaldoActual;
            RAISERROR(
                N'Capacidad insuficiente. Saldo actual: %d L, Carga intentada: %d L, Límite: %d L (Disponible: %d L).',
                16, 1, @SaldoActual, @Litros, @CapacidadLitros, @Disponible
            );
        END;

        -- 5. Insertar el movimiento de carga (Entrada)
        INSERT INTO dbo.CargaAgua (CisternaID, ProductoID, Litros, FechaCarga)
        VALUES (@CisternaID, @ProductoID, @Litros, SYSDATETIME());

        -- 6. Incrementar el saldo disponible en la cisterna
        UPDATE dbo.Cisterna
        SET SaldoLitros = SaldoLitros + @Litros
        WHERE CisternaID = @CisternaID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Si ocurre un error, se revierte cualquier cambio pendiente
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO

USE AquaCallao;
GO

PRINT '--------------------------------------------------';
PRINT 'CASO P2: PRUEBA DE CARGA (Fernando Álvaro Quispe Trigos)';
PRINT '--------------------------------------------------';

-- 1. ESTADO INICIAL
-- La cisterna parte con saldo 0 L y Capacidad de 2 000 L. Sin cargas registradas.
SELECT 'P2 - ESTADO ANTES (Cisterna)' AS Etapa, CisternaID, Placa, CapacidadLitros, SaldoLitros, Estado 
FROM dbo.Cisterna WHERE CisternaID = 1;

SELECT 'P2 - ESTADO ANTES (Cargas)' AS Etapa, COUNT(*) AS CantidadCargas 
FROM dbo.CargaAgua WHERE CisternaID = 1;

-- 2. CARGA VÁLIDA: Cargar 1 000 L
EXEC dbo.usp_RegistrarCarga 
    @CisternaID = 1, 
    @ProductoID = 1, 
    @Litros     = 1000;

-- 3. CARGA INVÁLIDA (EXCEDIDA): Intentar cargar 1 100 L adicionales
-- 1 000 L (actual) + 1 100 L (intento) = 2 100 L > 2 000 L (Capacidad máxima)
BEGIN TRY
    EXEC dbo.usp_RegistrarCarga 
        @CisternaID = 1, 
        @ProductoID = 1, 
        @Litros     = 1100;
END TRY
BEGIN CATCH
    PRINT CONCAT('Excepción capturada correctamente: ', ERROR_MESSAGE());
END CATCH;

-- 4. ESTADO FINAL
-- El saldo debe haberse quedado en 1 000 L y solo debe existir 1 fila en CargaAgua.
SELECT 'P2 - ESTADO DESPUÉS (Cisterna)' AS Etapa, CisternaID, Placa, CapacidadLitros, SaldoLitros, Estado 
FROM dbo.Cisterna WHERE CisternaID = 1;

SELECT 'P2 - ESTADO DESPUÉS (Cargas)' AS Etapa, CargaID, CisternaID, ProductoID, Litros, FechaCarga 
FROM dbo.CargaAgua WHERE CisternaID = 1;
GO