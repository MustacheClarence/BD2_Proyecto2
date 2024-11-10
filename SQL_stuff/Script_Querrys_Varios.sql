--SP para programar una sesion
CREATE OR ALTER PROCEDURE spCrearSesionProgramada
    @idPelicula INT,
    @idSala INT,
    @fechaInicio DATETIME,
    @duracion INT, -- en minutos
    @idUsuario INT -- Usuario que registra la sesión
AS
BEGIN
    -- Iniciar la transacción
    BEGIN TRANSACTION;

    BEGIN TRY
        -- Guardar el idUsuario en SESSION_CONTEXT para uso en el trigger
        EXEC sp_set_session_context @key = N'idUsuario', @value = @idUsuario;

        -- Calcular la fecha de fin de la sesión (incluye 15 minutos de limpieza)
        DECLARE @fechaFin DATETIME;
        SET @fechaFin = DATEADD(MINUTE, @duracion + 15, @fechaInicio);

        -- Verificación de traslapes
        IF EXISTS (
            SELECT 1 
            FROM SesionProgramada WITH (ROWLOCK, XLOCK) 
            WHERE idSala = @idSala
              AND (
                  (@fechaInicio BETWEEN FechaInicio AND FechaFin) OR 
                  (@fechaFin BETWEEN FechaInicio AND FechaFin) OR
                  (FechaInicio BETWEEN @fechaInicio AND @fechaFin) OR
                  (FechaFin BETWEEN @fechaInicio AND @fechaFin)
              )
        )
        BEGIN
            RAISERROR ('Error: La sesión se traslapa con otra en la misma sala.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Insertar la nueva sesión en la base de datos con estado "Activa" por defecto
        INSERT INTO SesionProgramada (idPelicula, idSala, FechaInicio, FechaFin, Estado)
        VALUES (@idPelicula, @idSala, @fechaInicio, @fechaFin, 'Activa');

        -- Confirmar la transacción si todo está correcto
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Si ocurre un error, revertir la transacción
        ROLLBACK TRANSACTION;
        
        -- Retornar el error al cliente
        DECLARE @ErrorMessage NVARCHAR(4000);
        DECLARE @ErrorSeverity INT;
        DECLARE @ErrorState INT;
        SELECT 
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE();
        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH;
END;
GO


--SP para registrar una venta de asiento
CREATE OR ALTER PROCEDURE asignarAsientoManual
    @IdSesionProgramada INT,
    @NoAsiento INT,
    @LetraAsiento NVARCHAR(5),
    @IdUsuario INT -- Usuario que realiza la compra
AS
BEGIN
    DECLARE @idAsiento INT;

    -- Verificar si el asiento existe en la tabla Asiento
    SELECT @idAsiento = idAsiento
    FROM Asiento
    WHERE LetraAsiento = @LetraAsiento
      AND NoAsiento = @NoAsiento;

    -- Si el asiento no existe en la tabla Asiento, salir con un mensaje de error
    IF @idAsiento IS NULL
    BEGIN
        PRINT 'Error: El asiento no existe en la tabla Asiento.';
        RETURN;
    END

    -- Verificar si el asiento ya está asignado en la sesión en la tabla SesionAsientos
    IF NOT EXISTS (
        SELECT 1 
        FROM SesionAsientos sa
        WHERE sa.IdSesionProgramada = @IdSesionProgramada 
          AND sa.IdAsiento = @idAsiento
    )
    BEGIN
        -- Insertar el asiento en la sesión específica con el estado "Ocupado"
        INSERT INTO SesionAsientos (IdSesionProgramada, IdAsiento, Estado)
        VALUES (@IdSesionProgramada, @idAsiento, 'Ocupado');

        -- Registrar la compra del asiento en VentaAsientos con la fecha de venta actual
        INSERT INTO VentaAsientos (IdSesionProgramada, IdAsiento, IdUsuario, FechaVenta)
        VALUES (@IdSesionProgramada, @idAsiento, @IdUsuario, GETDATE());

        PRINT 'El asiento ha sido asignado y la compra registrada en VentaAsientos.';
    END
    ELSE
    BEGIN
        PRINT 'El asiento ya está asignado en esta sesión.';
    END
END;
GO
