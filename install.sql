
/*
 * Uncomment the following if you are reinstalling Pacify and would like to
 * remove the existing installation.
 *
 * NOTE: THE [Pacify] SCHEMA SHOULD NOT BE USED FOR YOUR OWN RESOURCES AS
 * THEY COULD BE REMOVED BY THIS SCRIPT OR PACIFY ITSELF
 */
DROP SCHEMA IF EXISTS
	[Pacify];
GO

-- this is the URL where we will try to fetch the latest Bootstrap procedure from


-- create a schema to contain all Pacify resources
CREATE SCHEMA
	[Pacify];
GO

/*
 * ensure that Advanced Options and OLE Automation Procedures are enabled
 * so that we can issue HTTP requests
 */
EXEC sp_configure
	'Show Advanced Options',
	1;
RECONFIGURE;

EXEC sp_configure
	'OLE Automation Procedures',
	1;
RECONFIGURE;
GO

-- issue a GET request to fetch the Pacify.Bootstrap procedure from Git
-- first, create a new object to make the request
DECLARE @requestObjectType NVARCHAR(200) = 'MSXML2.ServerXMLHttp';
DECLARE @obj INT;
DECLARE @hresult INT;
EXEC @hresult = sp_OACreate
	@requestObjectType,
	@obj OUT;

-- ensure the object actually got created
IF @hresult != 0 BEGIN
	DECLARE @errorMessage NVARCHAR(MAX) = CONCAT(
		'Unable to create a new instance of ',
		@requestObjectType,
		' (error code ',
		@hresult,
		')'
	);

	EXEC sp_OADestroy
		@obj;

	THROW
		50001,
		@errorMessage,
		1;
END;

-- finally, destroy the object
EXEC sp_OADestroy
	@obj;
