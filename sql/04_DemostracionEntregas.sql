
-- Demostración de Casos P3 (Confirmación) y P4 (Cancelación)

USE AquaCallao;
GO

DECLARE @NewEntregaID INT;

-- 1. Estado inicial antes de la prueba P3 (verificar saldo de cisterna y beneficiario)
SELECT * FROM dbo.Cisterna WHERE CisternaID = 1;

PRINT '--- PRUEBA P3: Confirmación exitosa (Entregar 300 L) ---';
BEGIN TRY
    EXEC dbo.Sp_RegistrarEntrega 
        @ClienteID = 1, 
        @CisternaID = 1, 
        @ProductoID = 1, 
        @Litros = 300, 
        @EntregaID = @NewEntregaID OUTPUT;

    PRINT 'Éxito: Entrega registrada con ID = ' + CAST(@NewEntregaID AS VARCHAR(10));
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH;
GO

-- Comprobar estado tras P3: Saldo de la cisterna debe haberse reducido en 300 L y aparecer la fila en Entrega
SELECT * FROM dbo.Cisterna WHERE CisternaID = 1;
SELECT * FROM dbo.Entrega;
GO

-- 2. Prueba P4: Cancelación por saldo insuficiente (Intentar entregar 800 L cuando queda menos saldo)
DECLARE @NewEntregaID2 INT;
PRINT '--- PRUEBA P4: Cancelación por saldo insuficiente (Solicitar más de lo disponible) ---';
BEGIN TRY
    EXEC dbo.Sp_RegistrarEntrega 
        @ClienteID = 1, 
        @CisternaID = 1, 
        @ProductoID = 1, 
        @Litros = 800, 
        @EntregaID = @NewEntregaID2 OUTPUT;
END TRY
BEGIN CATCH
    PRINT '¡CANCELACIÓN EXITOSA (ROLLBACK APLICADO CORRECTAMENTE)!:';
    PRINT ERROR_MESSAGE();
END CATCH;
GO

-- Comprobar estado tras P4: El saldo y las filas de Entrega deben mantenerse intactos respecto al estado posterior a P3.
SELECT * FROM dbo.Cisterna WHERE CisternaID = 1;
SELECT COUNT(*) AS TotalEntregas FROM dbo.Entrega;
GO