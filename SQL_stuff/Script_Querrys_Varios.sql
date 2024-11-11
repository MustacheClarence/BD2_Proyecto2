-- SP para programar una sesion
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
        -- Verificación de que la fecha de inicio no sea anterior a la fecha actual
        IF @fechaInicio < CAST(GETDATE() AS DATE)
        BEGIN
            RAISERROR ('Error: La fecha de inicio no puede ser anterior a la fecha actual.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

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
        
        -- Manejo de errores
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

    -- Verificar si el asiento ya está en SesionAsientos en la misma sesión y está "Disponible"
    IF EXISTS (
        SELECT 1 
        FROM SesionAsientos sa
        WHERE sa.IdSesionProgramada = @IdSesionProgramada 
          AND sa.IdAsiento = @idAsiento
          AND sa.Estado = 'Ocupado'
    )
    BEGIN
        PRINT 'Error: El asiento ya está ocupado en esta sesión.';
        RETURN;
    END

    -- Si el asiento está "Disponible" en SesionAsientos, actualizar a "Ocupado";
    -- de lo contrario, insertarlo como "Ocupado"
    IF EXISTS (
        SELECT 1
        FROM SesionAsientos sa
        WHERE sa.IdSesionProgramada = @IdSesionProgramada
          AND sa.IdAsiento = @idAsiento
    )
    BEGIN
        -- Actualizar el estado del asiento a "Ocupado"
        UPDATE SesionAsientos
        SET Estado = 'Ocupado'
        WHERE IdSesionProgramada = @IdSesionProgramada
          AND IdAsiento = @idAsiento;
    END
    ELSE
    BEGIN
        -- Insertar el asiento en la sesión con estado "Ocupado"
        INSERT INTO SesionAsientos (IdSesionProgramada, IdAsiento, Estado)
        VALUES (@IdSesionProgramada, @idAsiento, 'Ocupado');
    END

    -- Registrar la compra del asiento en VentaAsiento con la fecha de venta actual
    INSERT INTO VentaAsiento (IdSesionProgramada, IdAsiento, IdUsuario, FechaVenta)
    VALUES (@IdSesionProgramada, @idAsiento, @IdUsuario, GETDATE());

    PRINT 'El asiento ha sido asignado y la compra registrada en VentaAsientos.';
END;
GO


--SP para cambio de asiento
CREATE OR ALTER PROCEDURE spCambioAsiento
    @idSesionProgramada INT,
    @idVentaAsiento INT,
    @idAsientoAnterior INT,
    @idAsientoNuevo INT,
    @idUsuario INT -- Usuario que realiza el cambio de asiento
AS
BEGIN
    -- Iniciar la transacción
    BEGIN TRANSACTION;

    BEGIN TRY
        -- Establecer el idUsuario en SESSION_CONTEXT para el trigger
        EXEC sp_set_session_context @key = N'idUsuario', @value = @idUsuario;

        -- Verificar que el nuevo asiento exista en la tabla Asiento
        IF NOT EXISTS (
            SELECT 1 
            FROM Asiento
            WHERE idAsiento = @idAsientoNuevo
        )
        BEGIN
            RAISERROR ('Error: El nuevo asiento no existe en la tabla Asiento.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Verificar si el nuevo asiento está ocupado en la sesión especificada
        IF EXISTS (
            SELECT 1
            FROM SesionAsientos
            WHERE idSesionProgramada = @idSesionProgramada
              AND idAsiento = @idAsientoNuevo
              AND Estado = 'Ocupado'
        )
        BEGIN
            RAISERROR ('Error: El nuevo asiento ya está ocupado en esta sesión.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Actualizar el estado del asiento anterior a "Disponible" en SesionAsiento
        IF EXISTS (
            SELECT 1 
            FROM SesionAsientos
            WHERE idSesionProgramada = @idSesionProgramada
              AND idAsiento = @idAsientoAnterior
        )
        BEGIN
            UPDATE SesionAsientos
            SET Estado = 'Disponible'
            WHERE idSesionProgramada = @idSesionProgramada
              AND idAsiento = @idAsientoAnterior;
        END

        -- Insertar o actualizar el nuevo asiento en SesionAsiento con estado "Ocupado"
        IF EXISTS (
            SELECT 1 
            FROM SesionAsientos
            WHERE idSesionProgramada = @idSesionProgramada
              AND idAsiento = @idAsientoNuevo
        )
        BEGIN
            -- Si el asiento ya existe en SesionAsiento, actualizar el estado a "Ocupado"
            UPDATE SesionAsientos
            SET Estado = 'Ocupado'
            WHERE idSesionProgramada = @idSesionProgramada
              AND idAsiento = @idAsientoNuevo;
        END
        ELSE
        BEGIN
            -- Si el asiento no existe en SesionAsiento, insertar el nuevo asiento con estado "Ocupado"
            INSERT INTO SesionAsientos (idSesionProgramada, idAsiento, Estado)
            VALUES (@idSesionProgramada, @idAsientoNuevo, 'Ocupado');
        END

        -- Registrar el cambio de asiento en la tabla CambioAsiento
        INSERT INTO CambioAsiento (idSesionProgramada, idVentaAsiento, idAsientoAnterior, idAsientoNuevo)
        VALUES (@idSesionProgramada, @idVentaAsiento, @idAsientoAnterior, @idAsientoNuevo);

        -- Confirmar la transacción si todo está correcto
        COMMIT TRANSACTION;

        PRINT 'Cambio de asiento realizado exitosamente.';
    END TRY
    BEGIN CATCH
        -- Si ocurre un error, revertir la transacción
        ROLLBACK TRANSACTION;

        -- Manejo de errores
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
