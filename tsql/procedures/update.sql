CREATE PROCEDURE Pacify.Update AS BEGIN
/*
 * impersonate the PacifyUser which the installer should have created. this
 * will ensure that the PacifyUser account owns all the related resources
 */
EXECUTE AS USER = 'PacifyUser';

PRINT 'hello, world';

-- stop impersonating the Pacify user
REVERT;

END
