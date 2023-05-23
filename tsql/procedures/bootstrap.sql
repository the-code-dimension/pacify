/*
 * Authors: Will
 * Created: 2023-05-22
 * Updated: 2023-05-22
 *
 * This is the Pacify bootstrap procedure. It is downloaded and executed by
 * the initial installer query and creates initial required procedures.
 */
CREATE PROCEDURE Pacify.Bootstrap
	@repo			NVARCHAR(4000),
	@targetBranch	NVARCHAR(4000),
	@httpProxy		NVARCHAR(4000),
	@uriPrefix		NVARCHAR(4000) = 'https://raw.githubusercontent.com/'
AS BEGIN
/*
 * impersonate the PacifyUser which the installer should have created. this
 * will ensure that the PacifyUser account owns all the related resources
 */
EXECUTE AS USER = 'PacifyUser';

-- output an initial header
DECLARE @hrule NVARCHAR(120) = REPLICATE('-', 120);
PRINT @hrule;
PRINT 'Pacify Bootstrap Procedure';
PRINT CONCAT(
    'Installing from target branch ''',
    @targetBranch,
    ''' of repo ',
	@repo
);
PRINT '';

-- set up a procedure to output log information
DROP PROCEDURE IF EXISTS
	Pacify.LogOperation;
DECLARE @createQuery NVARCHAR(MAX) = '
------------------------------------------------------------
-- NOTE: this procedure was automatically created by
-- Pacify.Bootstrap
------------------------------------------------------------
CREATE PROCEDURE Pacify.LogOperation
	@logMessage NVARCHAR(2000),
	@logDepth	INT
AS BEGIN
DECLARE @logOutput NVARCHAR(4000) = CONCAT(
	REPLICATE(''    '', @logDepth),
	''- '',
	@logMessage
);
PRINT @logOutput;
END
';
EXEC sp_executesql
	@createQuery;

EXEC Pacify.LogOperation
	'Created procedure Pacify.LogOperation',
	1;

-- set up a procedure to make an http request
DROP PROCEDURE IF EXISTS
	Pacify.MakeHttpRequest;
SET @createQuery = '
------------------------------------------------------------
-- NOTE: this procedure was automatically created by
-- Pacify.Bootstrap
------------------------------------------------------------
CREATE PROCEDURE Pacify.MakeHttpRequest
	@method		NVARCHAR(20),
	@targetUri	NVARCHAR(2000),
	@proxyUri	NVARCHAR(2000),
	@results	NVARCHAR(MAX) OUTPUT
AS BEGIN
-- first, create a new object to make the request
DECLARE @requestObjectType NVARCHAR(200) = ''MSXML2.ServerXMLHttp'';
DECLARE @obj INT;
DECLARE @hresult INT;
EXEC @hresult = sp_OACreate
    @requestObjectType,
    @obj OUT;

-- ensure the object actually got created
IF @hresult != 0 BEGIN
    DECLARE @errorMessage NVARCHAR(MAX) = CONCAT(
        ''Unable to create a new instance of '',
        @requestObjectType,
        '' (error code '',
        @hresult,
        '')''
    );

    EXEC sp_OADestroy
        @obj;

    THROW
        50001,
        @errorMessage,
        1;
END;

-- set up a proxy if the user provided one
IF @proxyUri IS NOT NULL BEGIN
    EXEC @hresult = sp_OAMethod
        @obj,
        ''setProxy'',
        NULL,
        ''2'',
        @proxyUri;

    -- ensure that setting the proxy was successful
    IF @hresult != 0 BEGIN
        SET @errorMessage = CONCAT(
            ''Failed calling method ''''setProxy'''' of '',
            @requestObjectType,
            '' (error code '',
            @hresult,
            '')''
        );

        EXEC sp_OADestroy
            @obj;

        THROW
            50003,
            @errorMessage,
            1;
    END;
END;

-- initiate a new GET request to the Bootstrap URI and ensure the call was successful
EXEC @hresult = sp_OAMethod
    @obj,
    ''open'',
    NULL,
    ''GET'',
    @targetUri,
    false;

IF @hresult != 0 BEGIN
    SET @errorMessage = CONCAT(
        ''Failed calling method ''''open'''' of '',
        @requestObjectType,
        '' (error code '',
        @hresult,
        '')''
    );

    EXEC sp_OADestroy
        @obj;

    THROW
        50003,
        @errorMessage,
        1;
END;

-- send the GET request and ensure that the call was successful
EXEC @hresult = sp_OAMethod
    @obj,
    ''send'',
    NULL,
    '''';
IF @hresult != 0 BEGIN
    SET @errorMessage = CONCAT(
        ''Failed calling method ''''send'''' of '',
        @requestObjectType,
        '' (error code '',
        @hresult,
        '')''
    );

    EXEC sp_OADestroy
        @obj;

    THROW
        50004,
        @errorMessage,
        1;
END;

-- get the results from the HTTP request and ensure that the call was successful
DROP TABLE IF EXISTS
	#tblResults;
CREATE TABLE #tblResults (
	[ResultField] NVARCHAR(MAX)
);
INSERT #tblResults (
	[ResultField]
)
EXEC @hresult = sp_OAGetProperty
    @obj,
    ''responseText'';
IF @hresult != 0 BEGIN
    SET @errorMessage = CONCAT(
        ''Failed calling method ''''responseText'''' of '',
        @requestObjectType,
        '' (error code '',
        @hresult,
        '')''
    );

    EXEC sp_OADestroy
        @obj;

    THROW
        50005,
        @errorMessage,
        1;
END;

-- destroy the request object as we have the results of the request
EXEC sp_OADestroy
    @obj;

-- get the resulting output
SELECT
	@results = [ResultField]
FROM
	#tblResults;

END
';
EXEC sp_executesql
	@createQuery;
EXEC Pacify.LogOperation
	'Created procedure Pacify.MakeHttpRequest',
	1;

-- create a table to contain registered repos to update from
DROP TABLE IF EXISTS
	Pacify.Repos;
CREATE TABLE Pacify.Repos (
	[RepoID]		INT PRIMARY KEY IDENTITY(1, 1),
	[RepoName]		NVARCHAR(4000) NOT NULL,
	[RepoBranch]	NVARCHAR(4000) NOT NULL,
	[RepoPrefix]	NVARCHAR(4000) NOT NULL
);

-- register the default repository
SET NOCOUNT ON;
INSERT INTO Pacify.Repos (
	[RepoName],
	[RepoBranch],
	[RepoPrefix]
)
VALUES (
	@repo,
	@targetBranch,
	@uriPrefix
);
DECLARE @logMessage NVARCHAR(MAX) = CONCAT(
	'Inserted record for source repo ',
	@repo
);
EXEC Pacify.LogOperation
	@logMessage,
	1;

-- get and create the Pacify.Update procedure
EXEC Pacify.LogOperation
	'Creating procedure Pacify.Update',
	1;
DECLARE @targetUri NVARCHAR(MAX) = CONCAT(
	@uriPrefix,
	@repo,
	'/',
	@targetBranch,
	'/procedures/update.sql'
);
DECLARE @results NVARCHAR(MAX);
EXEC Pacify.MakeHttpRequest
	'GET',
	@targetUri,
	@httpProxy,
	@results OUT;
SET @logMessage = CONCAT(
	'Fetched source from ',
	@targetUri
);
EXEC Pacify.LogOperation
	@logMessage,
	2;

-- output a final horizontal rule
PRINT @hrule;

-- stop impersonating the PacifyUser
REVERT;

END
