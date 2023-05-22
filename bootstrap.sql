/*
 *
 */
CREATE PROCEDURE Pacify.Bootstrap AS BEGIN
-- output an initial header
DECLARE @hrule NVARCHAR(120) = REPLICATE('-', 120);
PRINT @hrule;
PRINT 'Pacify Bootstrap Procedure';

PRINT @hrule;

END
