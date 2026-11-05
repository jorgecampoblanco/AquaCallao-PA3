USE AquaCallao;
GO

-- Procedimiento para consultar las entregas de un sector
CREATE OR ALTER PROCEDURE dbo.usp_ReporteEntregasPorSector
    @Sector NVARCHAR(60)
AS
BEGIN
    SET NOCOUNT ON;

    -- Limpiar y validar el sector recibido
    SET @Sector = LTRIM(RTRIM(@Sector));

    IF @Sector IS NULL OR @Sector = N''
        THROW 50001, 'Debe indicar un sector.', 1;

    -- Obtener la cantidad de entregas y el total de litros
    SELECT @Sector AS Sector,
           COUNT_BIG(e.EntregaID) AS TotalEntregas,
           COALESCE(SUM(CONVERT(BIGINT, e.Litros)), CONVERT(BIGINT, 0)) AS TotalLitros
    FROM dbo.Cliente AS c
    INNER JOIN dbo.Entrega AS e ON e.ClienteID = c.ClienteID
    WHERE c.Sector = @Sector;
END;
GO
