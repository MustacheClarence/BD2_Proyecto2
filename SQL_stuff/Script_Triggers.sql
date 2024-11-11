
-- ================================================TRIGGERS====================================================
-- ���������������������������������������������En VentaAsiento������������������������������������������������
-- Trigger para inserci�n en VentaAsiento
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

-- Trigger para actualizaci�n en VentaAsiento
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

-- Trigger para eliminaci�n en VentaAsiento
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

-- ���������������������������������������������En CambioAsiento������������������������������������������������
-- Trigger para inserci�n en CambioAsiento
CREATE OR ALTER TRIGGER trgCambioAsientoInsert
ON CambioAsiento
AFTER INSERT
AS
BEGIN
    DECLARE @accion NVARCHAR(50), @datosNuevos NVARCHAR(MAX), @idUsuario INT;
    
    -- Obtener idUsuario desde SESSION_CONTEXT
    SET @idUsuario = CAST(SESSION_CONTEXT(N'idUsuario') AS INT);

    -- Capturar los datos nuevos en formato JSON
    SELECT @datosNuevos = (SELECT * FROM INSERTED FOR JSON AUTO)
    FROM INSERTED;

    SET @accion = 'Cambio de Asiento Realizado';

    -- Insertar en LogTransacciones con idUsuario
    INSERT INTO LogTransacciones (FechaHora, idUsuario, AccionRealizada, DatosNuevos)
    VALUES (GETDATE(), @idUsuario, @accion, @datosNuevos);
END;
GO

-- Trigger para actualizaci�n en CambioAsiento
CREATE OR ALTER TRIGGER trgCambioAsientoUpdate
ON CambioAsiento
AFTER UPDATE
AS
BEGIN
    DECLARE @accion NVARCHAR(50), @datosAnteriores NVARCHAR(MAX), @datosNuevos NVARCHAR(MAX), @idUsuario INT;
    
    -- Obtener idUsuario desde SESSION_CONTEXT
    SET @idUsuario = CAST(SESSION_CONTEXT(N'idUsuario') AS INT);

    -- Capturar los datos anteriores y nuevos en formato JSON
    SELECT @datosAnteriores = (SELECT * FROM DELETED FOR JSON AUTO),
           @datosNuevos = (SELECT * FROM INSERTED FOR JSON AUTO)
    FROM INSERTED;

    SET @accion = 'Cambio de Asiento Actualizado';

    -- Insertar en LogTransacciones con idUsuario
    INSERT INTO LogTransacciones (FechaHora, idUsuario, AccionRealizada, DatosAnteriores, DatosNuevos)
    VALUES (GETDATE(), @idUsuario, @accion, @datosAnteriores, @datosNuevos);
END;
GO


-- Trigger para eliminaci�n en CambioAsiento
CREATE OR ALTER TRIGGER trgCambioAsientoDelete
ON CambioAsiento
AFTER DELETE
AS
BEGIN
    DECLARE @accion NVARCHAR(50), @datosAnteriores NVARCHAR(MAX), @idUsuario INT;
    
    -- Obtener idUsuario desde SESSION_CONTEXT
    SET @idUsuario = CAST(SESSION_CONTEXT(N'idUsuario') AS INT);

    -- Capturar los datos anteriores en formato JSON
    SELECT @datosAnteriores = (SELECT * FROM DELETED FOR JSON AUTO)
    FROM DELETED;

    SET @accion = 'Cambio de Asiento Eliminado';

    -- Insertar en LogTransacciones con idUsuario
    INSERT INTO LogTransacciones (FechaHora, idUsuario, AccionRealizada, DatosAnteriores)
    VALUES (GETDATE(), @idUsuario, @accion, @datosAnteriores);
END;
GO


-- ���������������������������������������������En SesionProgramada������������������������������������������������
-- Trigger para inserci�n en SesionProgramada
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

    -- Inserci�n en LogTransacciones con idUsuario
    INSERT INTO LogTransacciones (FechaHora, idUsuario, AccionRealizada, DatosNuevos)
    VALUES (GETDATE(), @idUsuario, @accion, @datosNuevos);
END;
GO


-- Trigger para actualizaci�n en SesionProgramada
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

    -- Inserci�n en LogTransacciones con idUsuario
    INSERT INTO LogTransacciones (FechaHora, idUsuario, AccionRealizada, DatosAnteriores, DatosNuevos)
    VALUES (GETDATE(), @idUsuario, @accion, @datosAnteriores, @datosNuevos);
END;
GO


-- Trigger para eliminaci�n en SesionProgramada
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

    -- Inserci�n en LogTransacciones con idUsuario
    INSERT INTO LogTransacciones (FechaHora, idUsuario, AccionRealizada, DatosAnteriores)
    VALUES (GETDATE(), @idUsuario, @accion, @datosAnteriores);
END;
GO



-- ���������������������������������������������En Usuario������������������������������������������������
-- Trigger para inserci�n en Usuario
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

-- Trigger para actualizaci�n en Usuario
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

-- Trigger para eliminaci�n en Usuario
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

-- ���������������������������������������������En Sala�����������������������������������������������
-- Trigger para actualizaci�n en Sala
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
