USE AquaCallao;
GO
SET NOCOUNT ON;
SET IMPLICIT_TRANSACTIONS OFF;

-- Comprobar los procedimientos necesarios
IF @@TRANCOUNT <> 0
    THROW 50010, 'Use una sesion sin transacciones abiertas.', 1;

IF OBJECT_ID(N'dbo.usp_RegistrarCliente', N'P') IS NULL
    THROW 50011, 'Falta el procedimiento de clientes.', 1;

IF OBJECT_ID(N'dbo.usp_RegistrarCarga', N'P') IS NULL
    THROW 50012, 'Falta el procedimiento de cargas.', 1;

IF OBJECT_ID(N'dbo.Sp_RegistrarEntrega', N'P') IS NULL
    THROW 50013, 'Falta el procedimiento de entregas.', 1;

IF OBJECT_ID(N'dbo.usp_ReporteEntregasPorSector', N'P') IS NULL
    THROW 50014, 'Falta el procedimiento del reporte.', 1;

DECLARE @Codigo VARCHAR(8) =
    LEFT(REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''), 8);

DECLARE @Sector NVARCHAR(60) = N'Integracion ' + @Codigo;
DECLARE @Documento VARCHAR(12);
DECLARE @ClienteID INT, @ProductoID INT, @CisternaID INT;
DECLARE @EntregaID INT, @Retorno INT;
DECLARE @ErrorEsperado BIT = 0;
DECLARE @Mensaje NVARCHAR(4000);

DECLARE @Reporte TABLE (
    Sector NVARCHAR(60),
    TotalEntregas BIGINT,
    TotalLitros BIGINT
);

BEGIN TRY
    -- Preparar datos exclusivos para esta ejecucion
    SET @Documento = CONVERT(
        VARCHAR(12),
        100000000000 + ABS(CONVERT(BIGINT, CHECKSUM(NEWID())))
    );

    WHILE EXISTS (
        SELECT 1 FROM dbo.Cliente WHERE Documento = @Documento
    )
    BEGIN
        SET @Documento = CONVERT(
            VARCHAR(12),
            100000000000 + ABS(CONVERT(BIGINT, CHECKSUM(NEWID())))
        );
    END;

    EXEC @Retorno = dbo.usp_RegistrarCliente
        @Nombre = N'Cliente de integracion',
        @Documento = @Documento,
        @Sector = @Sector,
        @ClienteID = @ClienteID OUTPUT;

    IF @Retorno <> 0 OR @ClienteID IS NULL
        THROW 50015, 'No se registro el cliente de prueba.', 1;

    INSERT INTO dbo.Producto (Nombre, UnidadMedida, Activo)
    VALUES (N'Agua integracion ' + @Codigo, 'L', 1);

    SET @ProductoID = CONVERT(INT, SCOPE_IDENTITY());

    INSERT INTO dbo.Cisterna
        (Placa, CapacidadLitros, SaldoLitros, Estado)
    VALUES ('I' + @Codigo, 2000, 0, 'Operativa');

    SET @CisternaID = CONVERT(INT, SCOPE_IDENTITY());

    -- I01: registrar una carga de 1000 litros
    EXEC dbo.usp_RegistrarCarga
        @CisternaID = @CisternaID,
        @ProductoID = @ProductoID,
        @Litros = 1000;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.Cisterna
        WHERE CisternaID = @CisternaID AND SaldoLitros = 1000
    )
        THROW 50016, 'El saldo no coincide con la carga.', 1;

    IF (
        SELECT COUNT(*) FROM dbo.CargaAgua
        WHERE CisternaID = @CisternaID AND Litros = 1000
    ) <> 1
        THROW 50017, 'La carga no se registro correctamente.', 1;

    SELECT N'I01: carga correcta' AS Prueba,
           CisternaID, CapacidadLitros, SaldoLitros
    FROM dbo.Cisterna
    WHERE CisternaID = @CisternaID;

    -- I02: entregar 800 litros y comprobar ambos cambios
    EXEC dbo.Sp_RegistrarEntrega
        @ClienteID = @ClienteID,
        @CisternaID = @CisternaID,
        @ProductoID = @ProductoID,
        @Litros = 800,
        @EntregaID = @EntregaID OUTPUT;

    IF @EntregaID IS NULL OR NOT EXISTS (
        SELECT 1 FROM dbo.Entrega
        WHERE EntregaID = @EntregaID
          AND ClienteID = @ClienteID
          AND CisternaID = @CisternaID
          AND ProductoID = @ProductoID
          AND Litros = 800
    )
        THROW 50018, 'No se registro la entrega esperada.', 1;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.Cisterna
        WHERE CisternaID = @CisternaID AND SaldoLitros = 200
    )
        THROW 50019, 'El saldo despues de entregar debe ser 200.', 1;

    SELECT N'I02: entrega confirmada' AS Prueba,
           e.EntregaID, e.Litros, c.SaldoLitros
    FROM dbo.Entrega AS e
    INNER JOIN dbo.Cisterna AS c
        ON c.CisternaID = e.CisternaID
    WHERE e.EntregaID = @EntregaID;

    -- I03: rechazar 300 litros cuando solo quedan 200
    SET @EntregaID = NULL;

    BEGIN TRY
        EXEC dbo.Sp_RegistrarEntrega
            @ClienteID = @ClienteID,
            @CisternaID = @CisternaID,
            @ProductoID = @ProductoID,
            @Litros = 300,
            @EntregaID = @EntregaID OUTPUT;
    END TRY
    BEGIN CATCH
        SET @Mensaje = ERROR_MESSAGE();

        IF @Mensaje NOT LIKE N'%saldo insuficiente%'
            THROW;

        SET @ErrorEsperado = 1;
    END CATCH;

    IF @ErrorEsperado = 0
        THROW 50020, 'No se rechazo la entrega sin saldo.', 1;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.Cisterna
        WHERE CisternaID = @CisternaID AND SaldoLitros = 200
    )
        THROW 50021, 'El rechazo modifico el saldo.', 1;

    IF (
        SELECT COUNT(*) FROM dbo.Entrega
        WHERE CisternaID = @CisternaID
    ) <> 1
        THROW 50022, 'El rechazo modifico las entregas.', 1;

    SELECT N'I03: entrega rechazada sin cambios' AS Prueba,
           @Mensaje AS Motivo,
           SaldoLitros,
           (SELECT COUNT(*) FROM dbo.Entrega
            WHERE CisternaID = @CisternaID) AS TotalEntregas
    FROM dbo.Cisterna
    WHERE CisternaID = @CisternaID;

    -- I04: comprobar el reporte con las operaciones anteriores
    INSERT INTO @Reporte
    EXEC dbo.usp_ReporteEntregasPorSector @Sector = @Sector;

    IF (SELECT COUNT(*) FROM @Reporte) <> 1
       OR NOT EXISTS (
           SELECT 1 FROM @Reporte
           WHERE Sector = @Sector
             AND TotalEntregas = 1
             AND TotalLitros = 800
       )
        THROW 50023, 'El reporte no coincide con la integracion.', 1;

    SELECT N'I04: reporte correcto' AS Prueba, *
    FROM @Reporte;

    IF @@TRANCOUNT <> 0
        THROW 50024, 'La prueba dejo una transaccion abierta.', 1;

    -- Eliminar solamente los datos creados para esta prueba
    BEGIN TRANSACTION;

    DELETE FROM dbo.Entrega WHERE CisternaID = @CisternaID;
    DELETE FROM dbo.CargaAgua WHERE CisternaID = @CisternaID;
    DELETE FROM dbo.Cisterna WHERE CisternaID = @CisternaID;
    DELETE FROM dbo.Producto WHERE ProductoID = @ProductoID;
    DELETE FROM dbo.Cliente WHERE ClienteID = @ClienteID;

    COMMIT TRANSACTION;

    SELECT N'Integracion terminada y datos de prueba eliminados'
           AS Resultado,
           @@TRANCOUNT AS TransaccionesAbiertas;
END TRY
BEGIN CATCH
    -- Deshacer una transaccion pendiente y limpiar los datos propios
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    BEGIN TRANSACTION;

    DELETE FROM dbo.Entrega WHERE CisternaID = @CisternaID;
    DELETE FROM dbo.CargaAgua WHERE CisternaID = @CisternaID;
    DELETE FROM dbo.Cisterna WHERE CisternaID = @CisternaID;
    DELETE FROM dbo.Producto WHERE ProductoID = @ProductoID;
    DELETE FROM dbo.Cliente WHERE ClienteID = @ClienteID;

    COMMIT TRANSACTION;
    THROW;
END CATCH;
GO