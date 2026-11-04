CREATE DATABASE AquaCallao;
GO

USE AquaCallao;
GO


/* ---------------------------------------------------------------------
   1. Creación de tablas 
   --------------------------------------------------------------------- */
 
-- 1.1 Cliente (beneficiarios)
CREATE TABLE dbo.Cliente (
    ClienteID  int IDENTITY(1,1) NOT NULL,
    Nombre     nvarchar(100)     NOT NULL,
    Documento  varchar(12)       NOT NULL,   -- varchar para conservar ceros iniciales
    Sector     nvarchar(60)      NOT NULL,
    Activo     bit               NOT NULL,
    CONSTRAINT PK_Cliente           PRIMARY KEY (ClienteID),
    CONSTRAINT UQ_Cliente_Documento UNIQUE (Documento)
);
GO
 
-- 1.2 Producto (catálogo)
CREATE TABLE dbo.Producto (
    ProductoID    int IDENTITY(1,1) NOT NULL,
    Nombre        nvarchar(60)      NOT NULL,
    UnidadMedida  varchar(10)       NOT NULL,
    Activo        bit               NOT NULL,
    CONSTRAINT PK_Producto        PRIMARY KEY (ProductoID),
    CONSTRAINT UQ_Producto_Nombre UNIQUE (Nombre)
);
GO
 
-- 1.3 Cisterna (vehículos y saldo)
CREATE TABLE dbo.Cisterna (
    CisternaID       int IDENTITY(1,1) NOT NULL,
    Placa            varchar(10)       NOT NULL,
    CapacidadLitros  int               NOT NULL,
    SaldoLitros      int               NOT NULL,
    Estado           varchar(12)       NOT NULL,
    CONSTRAINT PK_Cisterna        PRIMARY KEY (CisternaID),
    CONSTRAINT UQ_Cisterna_Placa  UNIQUE (Placa),
    CONSTRAINT CK_Cisterna_Capacidad CHECK (CapacidadLitros > 0),
    CONSTRAINT CK_Cisterna_Saldo     CHECK (SaldoLitros >= 0
                                            AND SaldoLitros <= CapacidadLitros),
    CONSTRAINT CK_Cisterna_Estado    CHECK (Estado IN ('Operativa', 'Inactiva'))
);
GO
 
-- 1.4 CargaAgua (entradas)
CREATE TABLE dbo.CargaAgua (
    CargaID     int IDENTITY(1,1) NOT NULL,
    CisternaID  int               NOT NULL,
    ProductoID  int               NOT NULL,
    Litros      int               NOT NULL,
    FechaCarga  datetime2         NOT NULL
        CONSTRAINT DF_CargaAgua_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_CargaAgua          PRIMARY KEY (CargaID),
    CONSTRAINT FK_CargaAgua_Cisterna FOREIGN KEY (CisternaID)
        REFERENCES dbo.Cisterna (CisternaID),
    CONSTRAINT FK_CargaAgua_Producto FOREIGN KEY (ProductoID)
        REFERENCES dbo.Producto (ProductoID),
    CONSTRAINT CK_CargaAgua_Litros   CHECK (Litros > 0)
);
GO
 
-- 1.5 Entrega (salidas)
CREATE TABLE dbo.Entrega (
    EntregaID     int IDENTITY(1,1) NOT NULL,
    ClienteID     int               NOT NULL,
    CisternaID    int               NOT NULL,
    ProductoID    int               NOT NULL,
    Litros        int               NOT NULL,
    FechaEntrega  datetime2         NOT NULL
        CONSTRAINT DF_Entrega_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Entrega          PRIMARY KEY (EntregaID),
    CONSTRAINT FK_Entrega_Cliente  FOREIGN KEY (ClienteID)
        REFERENCES dbo.Cliente (ClienteID),
    CONSTRAINT FK_Entrega_Cisterna FOREIGN KEY (CisternaID)
        REFERENCES dbo.Cisterna (CisternaID),
    CONSTRAINT FK_Entrega_Producto FOREIGN KEY (ProductoID)
        REFERENCES dbo.Producto (ProductoID),
    CONSTRAINT CK_Entrega_Litros   CHECK (Litros > 0)
);
GO


/* ---------------------------------------------------------------------
   2. Datos iniciales
      - 1 beneficiario activo del sector Ventanilla
      - 1 producto: Agua potable (unidad L), activo
      - 1 cisterna operativa de 2 000 L con saldo inicial 0
   --------------------------------------------------------------------- */

INSERT INTO dbo.Cliente (Nombre, Documento, Sector, Activo)
VALUES (N'Beneficiario Ventanilla 01', '00123456', N'Ventanilla', 1);
 
INSERT INTO dbo.Producto (Nombre, UnidadMedida, Activo)
VALUES (N'Agua potable', 'L', 1);
 
INSERT INTO dbo.Cisterna (Placa, CapacidadLitros, SaldoLitros, Estado)
VALUES ('ABC-123', 2000, 0, 'Operativa');
GO

/* ---------------------------------------------------------------------
   3. Mostrar el esquema
   --------------------------------------------------------------------- */
 
-- 3.1 Columnas, tipos y nulabilidad

SELECT  c.TABLE_NAME      AS Tabla,
        c.ORDINAL_POSITION AS Pos,
        c.COLUMN_NAME     AS Campo,
        c.DATA_TYPE       AS Tipo,
        c.CHARACTER_MAXIMUM_LENGTH AS Longitud,
        c.IS_NULLABLE     AS Nulo
FROM    INFORMATION_SCHEMA.COLUMNS c
WHERE   c.TABLE_SCHEMA = 'dbo'
ORDER BY CASE c.TABLE_NAME
            WHEN 'Cliente'    THEN 1
            WHEN 'Producto'   THEN 2
            WHEN 'Cisterna'   THEN 3
            WHEN 'CargaAgua'  THEN 4
            WHEN 'Entrega'    THEN 5 END,
         c.ORDINAL_POSITION;
GO
 
-- 3.2 Claves foráneas
SELECT  fk.name                            AS ClaveForanea,
        OBJECT_NAME(fk.parent_object_id)   AS TablaHija,
        OBJECT_NAME(fk.referenced_object_id) AS TablaPadre
FROM    sys.foreign_keys fk
ORDER BY TablaHija, ClaveForanea;
GO
 
-- 3.3 Restricciones CHECK
SELECT  OBJECT_NAME(parent_object_id) AS Tabla,
        name                          AS Restriccion,
        definition                    AS Definicion
FROM    sys.check_constraints
ORDER BY Tabla, Restriccion;
GO
 
-- 3.4 Datos iniciales
SELECT * FROM dbo.Cliente;
SELECT * FROM dbo.Producto;
SELECT * FROM dbo.Cisterna;
SELECT COUNT(*) AS FilasCargaAgua FROM dbo.CargaAgua;
SELECT COUNT(*) AS FilasEntrega   FROM dbo.Entrega;
GO
 
