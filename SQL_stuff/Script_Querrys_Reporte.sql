--Querrys para reportes
--1. Listado de sesiones en un rango de fecha y hora con Asiento ocupados
CREATE PROCEDURE spObtenerSesionesPorRango
    @FechaInicio DATETIME,
    @FechaFin DATETIME
AS
BEGIN
    -- Iniciar la transacci�n
    BEGIN TRANSACTION;

    BEGIN TRY
        -- Consulta de sesiones con asientos ocupados en el rango de fecha y hora
        SELECT 
            s.IdSesionProgramada,
            p.Nombre AS NombrePelicula, -- Obtener el nombre de la pel�cula
            s.IdSala,
            s.FechaInicio,
            s.FechaFin,
            COUNT(sa.idAsiento) AS AsientosOcupados,
            s.Estado
        FROM 
            SesionProgramada s WITH (ROWLOCK, XLOCK)
        LEFT JOIN 
            SesionAsientos sa WITH (ROWLOCK, XLOCK) 
            ON s.IdSesionProgramada = sa.idSesionProgramada AND sa.Estado = 'Ocupado' -- Filtrar solo asientos ocupados
        LEFT JOIN 
            Pelicula p WITH (ROWLOCK, XLOCK) ON s.IdPelicula = p.idPelicula
        WHERE 
            s.FechaInicio BETWEEN @FechaInicio AND @FechaFin
        GROUP BY 
            s.IdSesionProgramada, p.Nombre, s.IdSala, s.FechaInicio, s.FechaFin, s.Estado
        HAVING 
            COUNT(sa.idAsiento) > 0
        ORDER BY 
            s.FechaInicio;

        -- Confirmar la transacci�n si todo est� correcto
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Si ocurre un error, revertir la transacci�n
        ROLLBACK TRANSACTION;
        -- Retornar el error al cliente
        THROW;
    END CATCH;
END;
GO


--2. Listado de transacciones ingresadas en un rango de fecha y hora (no es la fecha y hora de la
--sesi�n sino de la compra) indicando datos de sesiones y cantidad de asientos de cada
--transacci�n.
CREATE PROCEDURE spObtenerTransaccionesPorRango
    @FechaInicio DATETIME,
    @FechaFin DATETIME
AS
BEGIN
    -- Iniciar la transacci�n
    BEGIN TRANSACTION;

    BEGIN TRY
        -- Consulta para listar transacciones en el rango de fecha y hora de compra con datos de sesi�n y cantidad de asientos
        SELECT 
            lt.idLogTransaccion AS IdTransaccion,
            lt.FechaHora AS FechaCompra, -- Fecha y hora de la compra
            s.IdSesionProgramada,
            p.Nombre AS NombrePelicula,
            s.IdSala,
            s.FechaInicio AS FechaSesion, -- Fecha y hora de la sesi�n
            JSON_VALUE(lt.DatosNuevos, '$.AsientosReservados') AS AsientosReservados -- Cantidad de asientos reservados en la transacci�n
        FROM 
            LogTransacciones lt WITH (ROWLOCK, XLOCK)
        JOIN 
            SesionProgramada s WITH (ROWLOCK, XLOCK) ON JSON_VALUE(lt.DatosNuevos, '$.IdSesionProgramada') = s.IdSesionProgramada
        LEFT JOIN 
            Pelicula p WITH (ROWLOCK, XLOCK) ON s.IdPelicula = p.IdPelicula
        WHERE 
            lt.FechaHora BETWEEN @FechaInicio AND @FechaFin
            AND lt.AccionRealizada = 'Venta Realizada'
        ORDER BY 
            lt.FechaHora;

        -- Confirmar la transacci�n si todo est� correcto
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Si ocurre un error, revertir la transacci�n
        ROLLBACK TRANSACTION;
        -- Retornar el error al cliente
        THROW;
    END CATCH;
END;
GO


--3. Dada una sala, obtener el promedio de asientos ocupados y cantidad de sesiones por mes para los �ltimos 3 meses.
CREATE PROCEDURE spObtenerPromedioAsientosYSesionesPorMes
    @IdSala INT
AS
BEGIN
    -- Iniciar la transacci�n
    BEGIN TRANSACTION;

    BEGIN TRY
        -- Consulta para obtener el promedio de asientos ocupados y la cantidad de sesiones por mes
        SELECT 
            DATEPART(YEAR, s.FechaInicio) AS A�o,
            DATEPART(MONTH, s.FechaInicio) AS Mes,
            AVG(CAST(sa.AsientosOcupados AS FLOAT)) AS PromedioAsientosOcupados,
            COUNT(DISTINCT s.IdSesionProgramada) AS CantidadSesiones
        FROM 
            SesionProgramada s WITH (ROWLOCK, XLOCK)
        LEFT JOIN (
            SELECT 
                sa.idSesionProgramada,
                COUNT(sa.idAsiento) AS AsientosOcupados
            FROM 
                SesionAsientos sa WITH (ROWLOCK, XLOCK)
            WHERE 
                sa.Estado = 'Ocupado'
            GROUP BY 
                sa.idSesionProgramada
        ) AS sa ON s.IdSesionProgramada = sa.idSesionProgramada
        WHERE 
            s.IdSala = @IdSala
            AND s.FechaInicio >= DATEADD(MONTH, -3, GETDATE())
        GROUP BY 
            DATEPART(YEAR, s.FechaInicio),
            DATEPART(MONTH, s.FechaInicio)
        ORDER BY 
            A�o DESC, Mes DESC;

        -- Confirmar la transacci�n si todo est� correcto
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Si ocurre un error, revertir la transacci�n
        ROLLBACK TRANSACTION;
        -- Retornar el error al cliente
        THROW;
    END CATCH;
END;
GO


--4. Sesiones con cantidad de asientos ocupados menor a un porcentaje dado para los �ltimos 3
--meses.
CREATE PROCEDURE spObtenerSesionesConBajoOcupacion
    @IdSala INT,
    @Porcentaje FLOAT
AS
BEGIN
    -- Iniciar la transacci�n
    BEGIN TRANSACTION;

    BEGIN TRY
        -- Consulta para obtener sesiones con baja ocupaci�n de asientos en los �ltimos 3 meses
        SELECT 
            s.IdSesionProgramada,
            p.Nombre AS NombrePelicula,
            s.IdSala,
            s.FechaInicio AS FechaSesion,
            COUNT(sa.idAsiento) AS AsientosOcupados,
            (CAST(COUNT(sa.idAsiento) AS FLOAT) / (10 * sala.AsientosPorFila)) * 100 AS PorcentajeOcupacion
        FROM 
            SesionProgramada s WITH (ROWLOCK, XLOCK)
        LEFT JOIN 
            SesionAsientos sa WITH (ROWLOCK, XLOCK) ON s.IdSesionProgramada = sa.idSesionProgramada AND sa.Estado = 'Ocupado'
        JOIN 
            Sala sala ON s.IdSala = sala.IdSala -- Tomar AsientosPorFila de la tabla Sala
        LEFT JOIN 
            Pelicula p WITH (ROWLOCK, XLOCK) ON s.IdPelicula = p.IdPelicula
        WHERE 
            s.IdSala = @IdSala
            AND s.FechaInicio >= DATEADD(MONTH, -3, GETDATE())
        GROUP BY 
            s.IdSesionProgramada, p.Nombre, s.IdSala, s.FechaInicio, sala.AsientosPorFila
        HAVING 
            (CAST(COUNT(sa.idAsiento) AS FLOAT) / (10 * sala.AsientosPorFila)) * 100 < @Porcentaje
        ORDER BY 
            PorcentajeOcupacion ASC;

        -- Confirmar la transacci�n si todo est� correcto
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Si ocurre un error, revertir la transacci�n
        ROLLBACK TRANSACTION;
        -- Retornar el error al cliente
        THROW;
    END CATCH;
END;
GO

-- 5. Top 5 pel�culas con mayor promedio de asientos vendidos por sesi�n para el �ltimo trimestre.
CREATE PROCEDURE spTop5PeliculasMayorPromedioAsientosVendidos
AS
BEGIN
    -- Iniciar la transacci�n
    BEGIN TRANSACTION;

    BEGIN TRY
        -- Consulta para obtener el top 5 de pel�culas con mayor promedio de asientos vendidos por sesi�n en el �ltimo trimestre
        SELECT TOP 5 
            p.Nombre AS NombrePelicula,
            AVG(CAST(venta.AsientosVendidos AS FLOAT)) AS PromedioAsientosVendidos
        FROM 
            Pelicula p WITH (ROWLOCK, XLOCK)
        JOIN 
            SesionProgramada s WITH (ROWLOCK, XLOCK) ON p.IdPelicula = s.IdPelicula
        LEFT JOIN (
            -- Subconsulta para contar asientos ocupados por sesi�n
            SELECT 
                sa.idSesionProgramada,
                COUNT(sa.idAsiento) AS AsientosVendidos
            FROM 
                SesionAsientos sa WITH (ROWLOCK, XLOCK)
            WHERE 
                sa.Estado = 'Ocupado'
            GROUP BY 
                sa.idSesionProgramada
        ) AS venta ON s.IdSesionProgramada = venta.idSesionProgramada
        WHERE 
            s.FechaInicio >= DATEADD(MONTH, -3, GETDATE()) -- Filtrar sesiones del �ltimo trimestre
        GROUP BY 
            p.Nombre
        ORDER BY 
            PromedioAsientosVendidos DESC;

        -- Confirmar la transacci�n si todo est� correcto
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Si ocurre un error, revertir la transacci�n
        ROLLBACK TRANSACTION;
        -- Retornar el error al cliente
        THROW;
    END CATCH;
END;
GO


-- 6. Log de transacciones de un rango de fecha y horas (la fecha y hora es del momento en
--que se gener� el registro del log) mostrando todos los datos de la transacci�n, sesi�n y
--pel�cula.
CREATE PROCEDURE spObtenerLogTransaccionesPorRango
    @FechaInicio DATETIME,
    @FechaFin DATETIME
AS
BEGIN
    -- Iniciar la transacci�n
    BEGIN TRANSACTION;

    BEGIN TRY
        -- Consulta para obtener el log de transacciones en el rango de fecha y hora
        SELECT 
            lt.idLogTransaccion AS IdTransaccion,
            lt.FechaHora AS FechaTransaccion,
            lt.idUsuario,
            u.Nombre AS NombreUsuario,
            lt.AccionRealizada,
            lt.DatosAnteriores,
            lt.DatosNuevos,
            s.IdSesionProgramada,
            s.IdSala,
            s.FechaInicio AS FechaSesion,
            s.FechaFin AS FechaFinSesion,
            p.Nombre AS NombrePelicula
        FROM 
            LogTransacciones lt WITH (ROWLOCK, XLOCK)
        LEFT JOIN 
            Usuario u ON lt.idUsuario = u.idUsuario
        LEFT JOIN 
            SesionProgramada s ON JSON_VALUE(lt.DatosNuevos, '$.IdSesionProgramada') = s.IdSesionProgramada
        LEFT JOIN 
            Pelicula p ON s.IdPelicula = p.IdPelicula
        WHERE 
            lt.FechaHora BETWEEN @FechaInicio AND @FechaFin
        ORDER BY 
            lt.FechaHora;

        -- Confirmar la transacci�n si todo est� correcto
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Si ocurre un error, revertir la transacci�n
        ROLLBACK TRANSACTION;
        -- Retornar el error al cliente
        THROW;
    END CATCH;
END;
GO


--Log de sesiones de un rango de fecha y horas (la fecha y hora es del momento en que
--se gener� el registro del log) mostrando todos los datos de la sesi�n y pel�cula.
CREATE PROCEDURE spObtenerLogSesionesPorRango
    @FechaInicio DATETIME,
    @FechaFin DATETIME
AS
BEGIN
    -- Iniciar la transacci�n
    BEGIN TRANSACTION;

    BEGIN TRY
        -- Consulta para obtener el log de sesiones en el rango de fecha y hora
        SELECT 
            lt.idLogTransaccion AS IdTransaccion,
            lt.FechaHora AS FechaLog,
            lt.AccionRealizada,
            lt.DatosAnteriores,
            lt.DatosNuevos,
            s.IdSesionProgramada,
            s.IdSala,
            s.FechaInicio AS FechaSesionInicio,
            s.FechaFin AS FechaSesionFin,
            s.Estado AS EstadoSesion,
            p.Nombre AS NombrePelicula
        FROM 
            LogTransacciones lt WITH (ROWLOCK, XLOCK)
        LEFT JOIN 
            SesionProgramada s ON JSON_VALUE(lt.DatosNuevos, '$.IdSesionProgramada') = s.IdSesionProgramada
        LEFT JOIN 
            Pelicula p ON s.IdPelicula = p.IdPelicula
        WHERE 
            lt.FechaHora BETWEEN @FechaInicio AND @FechaFin
            AND lt.AccionRealizada IN ('Sesion Creada', 'Sesion Actualizada')
        ORDER BY 
            lt.FechaHora;

        -- Confirmar la transacci�n si todo est� correcto
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Si ocurre un error, revertir la transacci�n
        ROLLBACK TRANSACTION;
        -- Retornar el error al cliente
        THROW;
    END CATCH;
END;
GO

