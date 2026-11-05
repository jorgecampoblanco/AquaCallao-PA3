USE AquaCallao;
GO


/* ---------------------------------------------------------------------
    Inserción rechazada por la clave foránea
      Se intenta registrar una carga para una cisterna inexistente
      (CisternaID = 999). Debe fallar con el error 547 y no debe quedar
      ningún movimiento adicional en CargaAgua.
   --------------------------------------------------------------------- */
 
-- Estado antes
SELECT COUNT(*) AS CargasAntes FROM dbo.CargaAgua;
 
BEGIN TRY
    INSERT INTO dbo.CargaAgua (CisternaID, ProductoID, Litros)
    VALUES (999, 1, 500);   -- cisterna inexistente
 
    PRINT 'ERROR DE PRUEBA: la inserción no debió ser aceptada.';
END TRY
BEGIN CATCH
    SELECT  ERROR_NUMBER()  AS NumeroError,     -- esperado: 547
            ERROR_MESSAGE() AS MensajeError;    -- conflicto con FK_CargaAgua_Cisterna
END CATCH;
 
-- Estado después (debe seguir en 0)
SELECT COUNT(*) AS CargasDespues FROM dbo.CargaAgua;
SELECT CisternaID, SaldoLitros FROM dbo.Cisterna;   -- el saldo sigue en 0
GO