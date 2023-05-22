/*
 *
 */
CREATE PROCEDURE Pacify.Bootstrap AS BEGIN

DECLARE @hrule NVARCHAR(120) = REPLICATE('-', 120);
PRINT @hrule;
PRINT 'Pacify Bootstrap Procedure';

PRINT @hrule;

END
