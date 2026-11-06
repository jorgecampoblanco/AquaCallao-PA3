
-- Archivo: 04_RegistrarEntrega.sql
-- Proyecto: AquaCallao - PA3 (Grupo 02)
-- Descripción: Procedimiento para registrar entregas con validación transaccional.


USE AquaCallao;
GO

IF OBJECT_ID('dbo.Sp_RegistrarEntrega', 'P') IS NOT NULL
    DROP PROCEDURE dbo.Sp_RegistrarEntrega;
GO

CREATE PROCEDURE dbo.Sp_RegistrarEntrega
    @ClienteID    INT,
    @CisternaID   INT,
    @ProductoID   INT,
    @Litros       INT,
    @EntregaID    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Validar que la cantidad de litros sea positiva
    IF @Litros <= 0
    BEGIN
        RAISERROR('La cantidad de litros a entregar debe ser mayor a cero.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        -- Iniciar transacción explícita
        BEGIN TRANSACTION;

        -- 1. Actualizar el saldo de la cisterna exigiendo litros positivos, estado operativo y saldo suficiente
        UPDATE dbo.Cisterna
        SET SaldoLitros = SaldoLitros - @Litros
        WHERE CisternaID = @CisternaID 
          AND Estado = 'Operativa' 
          AND SaldoLitros >= @Litros;

        -- Si ninguna fila cumple la condición, significa que no hay saldo, la cisterna no existe o está inactiva
        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR('Error: Cisterna inactiva, no encontrada o saldo insuficiente para la entrega.', 16, 1);
        END

        -- 2. Insertar el registro de la entrega en la tabla oficial dbo.Entrega
        INSERT INTO dbo.Entrega (ClienteID, CisternaID, ProductoID, Litros)
        VALUES (@ClienteID, @CisternaID, @ProductoID, @Litros);

        -- Obtener el ID generado para la salida
        SET @EntregaID = SCOPE_IDENTITY();

        -- Confirmar transacción si todo finaliza correctamente
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Revertir cambios si hay una transacción activa
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END

        -- Propagar el error original
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH;
END;
GO