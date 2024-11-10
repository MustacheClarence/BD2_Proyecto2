-- Crear la base de datos CineGT
CREATE DATABASE CineGT;
GO

-- Usar la base de datos CineGT
USE CineGT;
GO

-- Tabla Usuario
CREATE TABLE Usuario (
    idUsuario INT PRIMARY KEY IDENTITY(1,1),
    Nombre NVARCHAR(100) NOT NULL,
    Apellido NVARCHAR(100) NOT NULL,
    SegundoApellido NVARCHAR(100) NULL,
    FechaNacimiento DATE NOT NULL,
    NombreUsuario NVARCHAR(50) NOT NULL UNIQUE,
    Contraseña NVARCHAR(100) NOT NULL,
    EsAdmin BIT NOT NULL DEFAULT 0 -- 0 = No administrador, 1 = Administrador
)

-- Tabla Pelicula
CREATE TABLE Pelicula (
    idPelicula INT PRIMARY KEY IDENTITY(1,1),
    Nombre NVARCHAR(200) NOT NULL,
    idClasificacion INT NOT NULL, -- FK a la tabla Clasificacion
    Duracion INT NOT NULL, -- Duración en minutos
    Descripcion NVARCHAR(500) NULL,
    FOREIGN KEY (idClasificacion) REFERENCES Clasificacion(idClasificacion)
);

-- Tabla Clasificacion
CREATE TABLE Clasificacion (
    idClasificacion INT PRIMARY KEY IDENTITY(1,1),
    Descripcion NVARCHAR(50) NOT NULL
);

-- Tabla Asiento
CREATE TABLE Asiento (
    idAsiento INT PRIMARY KEY IDENTITY(1,1),
    NoAsiento NVARCHAR(10) NOT NULL,
    LetraAsiento NVARCHAR(5) NOT NULL,
    Estado NVARCHAR(10) NOT NULL CHECK (Estado IN ('Activo', 'Inactivo'))
);

-- Tabla Sala
CREATE TABLE Sala (
    idSala INT PRIMARY KEY IDENTITY(1,1),
    CantidadAsientos INT NOT NULL,
    Estado NVARCHAR(10) NOT NULL CHECK (Estado IN ('Activa', 'Inactiva')),
    Filas NVARCHAR(20) NOT NULL, -- Rango de letras (ej. 'A-J')
    AsientosPorFila INT NOT NULL -- Número de asientos en cada fila
);

-- Tabla SesionProgramada
CREATE TABLE SesionProgramada (
    idSesionProgramada INT PRIMARY KEY IDENTITY(1,1),
    idPelicula INT NOT NULL, -- FK a la tabla Pelicula
    idSala INT NOT NULL, -- FK a la tabla Sala
    FechaInicio DATETIME NOT NULL,
    FechaFin DATETIME NOT NULL,
    Estado NVARCHAR(20) NOT NULL, CHECK (Estado IN ('Activa', 'Inactiva')),
    FOREIGN KEY (idPelicula) REFERENCES Pelicula(idPelicula),
    FOREIGN KEY (idSala) REFERENCES Sala(idSala)
);

-- Tabla VentaAsiento
CREATE TABLE VentaAsiento (
    idVentaAsiento INT PRIMARY KEY IDENTITY(1,1),
    idSesionProgramada INT NOT NULL, -- FK a la tabla SesionProgramada
    idAsiento INT NOT NULL, -- FK a la tabla Asiento
    idUsuario INT NOT NULL, -- FK a la tabla Usuario
    FechaVenta DATETIME NOT NULL,
    FOREIGN KEY (idSesionProgramada) REFERENCES SesionProgramada(idSesionProgramada),
    FOREIGN KEY (idAsiento) REFERENCES Asiento(idAsiento),
    FOREIGN KEY (idUsuario) REFERENCES Usuario(idUsuario)
);

-- Tabla CambioAsiento
CREATE TABLE CambioAsiento (
    idCambioAsiento INT PRIMARY KEY IDENTITY(1,1),
    idVentaAsiento INT NOT NULL, -- FK a la tabla VentaAsiento
    idAsientoAnterior INT NOT NULL, -- FK a la tabla Asiento (anterior)
    idAsientoNuevo INT NOT NULL, -- FK a la tabla Asiento (nuevo)
    FechaCambio DATETIME NOT NULL,
    FOREIGN KEY (idVentaAsiento) REFERENCES VentaAsiento(idVentaAsiento),
    FOREIGN KEY (idAsientoAnterior) REFERENCES Asiento(idAsiento),
    FOREIGN KEY (idAsientoNuevo) REFERENCES Asiento(idAsiento)
);

-- Tabla Sesion-Asientos (sin clave primaria única, usando ambas FK)
CREATE TABLE SesionAsientos (
    idSesionProgramada INT NOT NULL, -- FK a la tabla SesionProgramada
    idAsiento INT NOT NULL, -- FK a la tabla Asiento
    Estado NVARCHAR(10) NOT NULL CHECK (Estado IN ('Ocupado', 'Disponible')),
    PRIMARY KEY (idSesionProgramada, idAsiento),
    FOREIGN KEY (idSesionProgramada) REFERENCES SesionProgramada(idSesionProgramada),
    FOREIGN KEY (idAsiento) REFERENCES Asiento(idAsiento)
);


-- Tabla Transacciones
CREATE TABLE LogTransacciones (
    idLogTransaccion INT PRIMARY KEY IDENTITY(1,1), -- Identificador único para cada log
    FechaHora DATETIME NOT NULL DEFAULT GETDATE(), -- Marca de tiempo del cambio
    idUsuario INT, -- FK al usuario que realizó la acción (si aplica)
    AccionRealizada NVARCHAR(50) NOT NULL, -- Tipo de acción (ej. 'Venta Realizada', 'Cambio de Asiento', etc.)
    DatosAnteriores NVARCHAR(MAX) NULL, -- Datos previos al cambio en formato JSON (para auditoría)
    DatosNuevos NVARCHAR(MAX) NULL, -- Datos posteriores al cambio en formato JSON
    FOREIGN KEY (idUsuario) REFERENCES Usuario(idUsuario) -- FK a la tabla Usuario
);




-- ================================================TRIGGERS====================================================
-- ºººººººººººººººººººººººººººººººººººººººººººººEn VentaAsientoºººººººººººººººººººººººººººººººººººººººººººººººº
-- Trigger para inserción en VentaAsiento
CREATE OR ALTER TRIGGER trgVentaAsientoInsert
ON VentaAsiento
AFTER INSERT
AS
BEGIN
    DECLARE @idUsuario INT, @accion NVARCHAR(50), @datosNuevos NVARCHAR(MAX);
    
    -- Captura el usuario y los datos nuevos en formato JSON
    SELECT @idUsuario = idUsuario,
           @datosNuevos = (SELECT * FROM INSERTED FOR JSON AUTO)
    FROM INSERTED;

    SET @accion = 'Venta Realizada';

    INSERT INTO LogTransacciones (idUsuario, AccionRealizada, DatosNuevos)
    VALUES (@idUsuario, @accion, @datosNuevos);
END;
GO

-- Trigger para actualización en VentaAsiento
CREATE OR ALTER TRIGGER trgVentaAsientoUpdate
ON VentaAsiento
AFTER UPDATE
AS
BEGIN
    DECLARE @idUsuario INT, @accion NVARCHAR(50), @datosAnteriores NVARCHAR(MAX), @datosNuevos NVARCHAR(MAX);
    
    -- Captura los datos anteriores y nuevos en formato JSON
    SELECT @idUsuario = idUsuario,
           @datosAnteriores = (SELECT * FROM DELETED FOR JSON AUTO),
           @datosNuevos = (SELECT * FROM INSERTED FOR JSON AUTO)
    FROM INSERTED;

    SET @accion = 'Venta Actualizada';

    INSERT INTO LogTransacciones (idUsuario, AccionRealizada, DatosAnteriores, DatosNuevos)
    VALUES (@idUsuario, @accion, @datosAnteriores, @datosNuevos);
END;
GO

-- Trigger para eliminación en VentaAsiento
CREATE OR ALTER TRIGGER trgVentaAsientoDelete
ON VentaAsiento
AFTER DELETE
AS
BEGIN
    DECLARE @idUsuario INT, @accion NVARCHAR(50), @datosAnteriores NVARCHAR(MAX);
    
    -- Captura los datos anteriores en formato JSON
    SELECT @idUsuario = idUsuario,
           @datosAnteriores = (SELECT * FROM DELETED FOR JSON AUTO)
    FROM DELETED;

    SET @accion = 'Venta Eliminada';

    INSERT INTO LogTransacciones (idUsuario, AccionRealizada, DatosAnteriores)
    VALUES (@idUsuario, @accion, @datosAnteriores);
END;
GO

-- ºººººººººººººººººººººººººººººººººººººººººººººEn CambioAsientoºººººººººººººººººººººººººººººººººººººººººººººººº
-- Trigger para inserción en CambioAsiento
CREATE OR ALTER TRIGGER trgCambioAsientoInsert
ON CambioAsiento
AFTER INSERT
AS
BEGIN
    DECLARE @accion NVARCHAR(50), @datosNuevos NVARCHAR(MAX);
    
    SELECT @datosNuevos = (SELECT * FROM INSERTED FOR JSON AUTO)
    FROM INSERTED;

    SET @accion = 'Cambio de Asiento Realizado';

    INSERT INTO LogTransacciones (AccionRealizada, DatosNuevos)
    VALUES (@accion, @datosNuevos);
END;
GO

-- Trigger para actualización en CambioAsiento
CREATE OR ALTER TRIGGER trgCambioAsientoUpdate
ON CambioAsiento
AFTER UPDATE
AS
BEGIN
    DECLARE @accion NVARCHAR(50), @datosAnteriores NVARCHAR(MAX), @datosNuevos NVARCHAR(MAX);
    
    SELECT @datosAnteriores = (SELECT * FROM DELETED FOR JSON AUTO),
           @datosNuevos = (SELECT * FROM INSERTED FOR JSON AUTO)
    FROM INSERTED;

    SET @accion = 'Cambio de Asiento Actualizado';

    INSERT INTO LogTransacciones (AccionRealizada, DatosAnteriores, DatosNuevos)
    VALUES (@accion, @datosAnteriores, @datosNuevos);
END;
GO

-- Trigger para eliminación en CambioAsiento
CREATE OR ALTER TRIGGER trgCambioAsientoDelete
ON CambioAsiento
AFTER DELETE
AS
BEGIN
    DECLARE @accion NVARCHAR(50), @datosAnteriores NVARCHAR(MAX);
    
    SELECT @datosAnteriores = (SELECT * FROM DELETED FOR JSON AUTO)
    FROM DELETED;

    SET @accion = 'Cambio de Asiento Eliminado';

    INSERT INTO LogTransacciones (AccionRealizada, DatosAnteriores)
    VALUES (@accion, @datosAnteriores);
END;
GO

-- ºººººººººººººººººººººººººººººººººººººººººººººEn SesionProgramadaºººººººººººººººººººººººººººººººººººººººººººººººº
-- Trigger para inserción en SesionProgramada
CREATE  OR ALTER TRIGGER trgSesionProgramadaInsert
ON SesionProgramada
AFTER INSERT
AS
BEGIN
    DECLARE @accion NVARCHAR(50), @datosNuevos NVARCHAR(MAX), @idUsuario INT;

    -- Obtener idUsuario desde SESSION_CONTEXT
    SET @idUsuario = CAST(SESSION_CONTEXT(N'idUsuario') AS INT);

    -- Captura los datos nuevos en formato JSON
    SELECT @datosNuevos = (SELECT * FROM INSERTED FOR JSON AUTO)
    FROM INSERTED;

    SET @accion = 'Sesion Creada';

    -- Inserción en LogTransacciones con idUsuario
    INSERT INTO LogTransacciones (FechaHora, idUsuario, AccionRealizada, DatosNuevos)
    VALUES (GETDATE(), @idUsuario, @accion, @datosNuevos);
END;
GO


-- Trigger para actualización en SesionProgramada
CREATE OR ALTER TRIGGER trgSesionProgramadaUpdate
ON SesionProgramada
AFTER UPDATE
AS
BEGIN
    DECLARE @accion NVARCHAR(50), @datosAnteriores NVARCHAR(MAX), @datosNuevos NVARCHAR(MAX), @idUsuario INT;

    -- Obtener idUsuario desde SESSION_CONTEXT
    SET @idUsuario = CAST(SESSION_CONTEXT(N'idUsuario') AS INT);

    -- Captura los datos anteriores y nuevos en formato JSON
    SELECT @datosAnteriores = (SELECT * FROM DELETED FOR JSON AUTO),
           @datosNuevos = (SELECT * FROM INSERTED FOR JSON AUTO)
    FROM INSERTED;

    SET @accion = 'Sesion Actualizada';

    -- Inserción en LogTransacciones con idUsuario
    INSERT INTO LogTransacciones (FechaHora, idUsuario, AccionRealizada, DatosAnteriores, DatosNuevos)
    VALUES (GETDATE(), @idUsuario, @accion, @datosAnteriores, @datosNuevos);
END;
GO


-- Trigger para eliminación en SesionProgramada
CREATE OR ALTER TRIGGER trgSesionProgramadaDelete
ON SesionProgramada
AFTER DELETE
AS
BEGIN
    DECLARE @accion NVARCHAR(50), @datosAnteriores NVARCHAR(MAX), @idUsuario INT;

    -- Obtener idUsuario desde SESSION_CONTEXT
    SET @idUsuario = CAST(SESSION_CONTEXT(N'idUsuario') AS INT);

    -- Captura los datos anteriores en formato JSON
    SELECT @datosAnteriores = (SELECT * FROM DELETED FOR JSON AUTO)
    FROM DELETED;

    SET @accion = 'Sesion Eliminada';

    -- Inserción en LogTransacciones con idUsuario
    INSERT INTO LogTransacciones (FechaHora, idUsuario, AccionRealizada, DatosAnteriores)
    VALUES (GETDATE(), @idUsuario, @accion, @datosAnteriores);
END;
GO



-- ºººººººººººººººººººººººººººººººººººººººººººººEn Usuarioºººººººººººººººººººººººººººººººººººººººººººººººº
-- Trigger para inserción en Usuario
CREATE OR ALTER TRIGGER trgUsuarioInsert
ON Usuario
AFTER INSERT
AS
BEGIN
    DECLARE @idUsuario INT, @accion NVARCHAR(50), @datosNuevos NVARCHAR(MAX);
    
    -- Captura el id del usuario y los datos nuevos en formato JSON
    SELECT @idUsuario = idUsuario,
           @datosNuevos = (SELECT * FROM INSERTED FOR JSON AUTO)
    FROM INSERTED;

    SET @accion = 'Usuario Creado';

    INSERT INTO LogTransacciones (idUsuario, AccionRealizada, DatosNuevos)
    VALUES (@idUsuario, @accion, @datosNuevos);
END;
GO

-- Trigger para actualización en Usuario
CREATE OR ALTER TRIGGER trgUsuarioUpdate
ON Usuario
AFTER UPDATE
AS
BEGIN
    DECLARE @idUsuario INT, @accion NVARCHAR(50), @datosAnteriores NVARCHAR(MAX), @datosNuevos NVARCHAR(MAX);
    
    -- Captura los datos anteriores y nuevos en formato JSON
    SELECT @idUsuario = idUsuario,
           @datosAnteriores = (SELECT * FROM DELETED FOR JSON AUTO),
           @datosNuevos = (SELECT * FROM INSERTED FOR JSON AUTO)
    FROM INSERTED;

    SET @accion = 'Usuario Actualizado';

    INSERT INTO LogTransacciones (idUsuario, AccionRealizada, DatosAnteriores, DatosNuevos)
    VALUES (@idUsuario, @accion, @datosAnteriores, @datosNuevos);
END;
GO

-- Trigger para eliminación en Usuario
CREATE OR ALTER TRIGGER trgUsuarioDelete
ON Usuario
AFTER DELETE
AS
BEGIN
    DECLARE @idUsuario INT, @accion NVARCHAR(50), @datosAnteriores NVARCHAR(MAX);
    
    -- Captura los datos anteriores en formato JSON
    SELECT @idUsuario = idUsuario,
           @datosAnteriores = (SELECT * FROM DELETED FOR JSON AUTO)
    FROM DELETED;

    SET @accion = 'Usuario Eliminado';

    INSERT INTO LogTransacciones (idUsuario, AccionRealizada, DatosAnteriores)
    VALUES (@idUsuario, @accion, @datosAnteriores);
END;
GO

-- ºººººººººººººººººººººººººººººººººººººººººººººEn Salaººººººººººººººººººººººººººººººººººººººººººººººº
-- Trigger para actualización en Sala
CREATE OR ALTER TRIGGER trgSalaUpdate
ON Sala
AFTER UPDATE
AS
BEGIN
    DECLARE @accion NVARCHAR(50), @datosAnteriores NVARCHAR(MAX), @datosNuevos NVARCHAR(MAX);
    
    -- Captura los datos anteriores y nuevos en formato JSON
    SELECT @datosAnteriores = (SELECT * FROM DELETED FOR JSON AUTO),
           @datosNuevos = (SELECT * FROM INSERTED FOR JSON AUTO)
    FROM INSERTED;

    SET @accion = 'Sala Actualizada';

    INSERT INTO LogTransacciones (AccionRealizada, DatosAnteriores, DatosNuevos)
    VALUES (@accion, @datosAnteriores, @datosNuevos);
END;
GO
