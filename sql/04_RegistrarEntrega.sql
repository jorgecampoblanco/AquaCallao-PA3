
-- Archivo: 04_RegistrarEntrega.sql
-- Descripción: Procedimiento actualizado con validación de estados (activos) y nulos.


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

    -- 1. Inicializar el parámetro de salida en NULL
    SET @EntregaID = NULL;

    -- 2. Rechazar explícitamente si @Litros es NULL o menor/igual a cero
    IF @Litros IS NULL OR @Litros <= 0
    BEGIN
        RAISERROR('La cantidad de litros no puede ser nula ni menor o igual a cero.', 16, 1);
        RETURN;
    END

    -- 3. Validar que el cliente exista y esté activo (Activo = 1)
    IF NOT EXISTS (SELECT 1 FROM dbo.Cliente WHERE ClienteID = @ClienteID AND Activo = 1)
    BEGIN
        RAISERROR('Error: El cliente especificado no existe o se encuentra inactivo.', 16, 1);
        RETURN;
    END

    -- 4. Validar que el producto exista y esté activo (Activo = 1)
    IF NOT EXISTS (SELECT 1 FROM dbo.Producto WHERE ProductoID = @ProductoID AND Activo = 1)
    BEGIN
        RAISERROR('Error: El producto especificado no existe o se encuentra inactivo.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        -- Iniciar transacción explícita
        BEGIN TRANSACTION;

        -- 5. Actualizar el saldo de la cisterna exigiendo estado operativo y saldo suficiente
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

        -- 6. Insertar el registro de la entrega en la tabla oficial dbo.Entrega
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