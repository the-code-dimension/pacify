
/*
 * Authors: Will
 * Created: 2023-05-22
 * Updated: 2023-05-22
 *
 * This is the installation query for the Pacify package manager for SQL Server.
 * It performs initial configuration and fetches the latest version of
 * Pacify.Bootstrap from Github which sets up all other necessary components.
 *
 * Notes:
 *	- To reinstall, uncomment the first block below and run this entire script.
 *	- Set the @httpProxy variable if your network requires a proxy in order to
 *	  issue requests to Github
 */

/*
 * Uncomment the following block if you are reinstalling Pacify and would like to
 * remove the existing installation.
 *
 * NOTE: THE [Pacify] SCHEMA SHOULD NOT BE USED FOR YOUR OWN RESOURCES AS
 * THEY COULD BE REMOVED BY THIS SCRIPT OR PACIFY ITSELF
 */
/*
SET NOCOUNT ON;
DECLARE @hrule NCHAR(120) = REPLICATE('-', 120);
PRINT @hrule;
DROP TABLE IF EXISTS
    #tblDropQueries;
CREATE TABLE #tblDropQueries (
    [Index]		INT,
    [DropQuery]	NVARCHAR(MAX)
);
WITH cteObjectTypes AS (
    SELECT
        'P' AS [Type],
        'PROCEDURE' AS [Name]
    UNION
    SELECT
        'T',
        'TABLE'
    UNION
    SELECT
        'V',
        'VIEW'
)
INSERT INTO
    #tblDropQueries
SELECT
    ROW_NUMBER() OVER (
        ORDER BY
            a.[name]
    ) AS [Index],
    CONCAT(
        'DROP ',
        c.[Name],
        ' Pacify.[', a.[name], '];'
    ) AS DropQuery
FROM
    sys.objects AS a
LEFT JOIN sys.schemas AS b ON
    a.[schema_id] = b.[schema_id]
LEFT JOIN cteObjectTypes AS c ON
    a.[type] = c.[Type]
WHERE
    b.[name] = 'Pacify';

-- loop over all of the derived DROP queries
DECLARE @index INT = 1;
WHILE @index <= (SELECT MAX([Index]) FROM #tblDropQueries) BEGIN
    DECLARE @dropQuery NVARCHAR(MAX) = (
        SELECT
            [DropQuery]
        FROM
            #tblDropQueries
        WHERE
            [Index] = @index
    );
    PRINT @dropQuery;

    -- execute the DROP query
    EXEC sp_executesql
        @dropquery;

    SET @index = @index + 1;
END;

PRINT 'DROP SCHEMA IF EXISTS [Pacify];';
DROP SCHEMA IF EXISTS
    [Pacify];
GO
*/


-- create a schema to contain all Pacify resources
CREATE SCHEMA
    [Pacify];
GO

/*
 * ensure that Advanced Options and OLE Automation Procedures are enabled
 * so that we can issue HTTP requests
 */
DECLARE @hrule NCHAR(120) = REPLICATE('-', 120);
PRINT @hrule;
EXEC sp_configure
    'Show Advanced Options',
    1;
RECONFIGURE;

EXEC sp_configure
    'OLE Automation Procedures',
    1;
RECONFIGURE;
PRINT @hrule;

/*
 * issue a GET request to fetch the Pacify.Bootstrap procedure from Git
 */
-- OPTIONAL: this is an HTTP proxy to use (NULL if none to use)
DECLARE @httpProxy NVARCHAR(200) = NULL;

-- this is the URL where we will try to fetch the latest Bootstrap procedure from
DECLARE @bootstrapUri NVARCHAR(200) = 'https://raw.githubusercontent.com/the-code-dimension/pacify/main/bootstrap.sql';

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

-- set up a proxy if the user provided one
IF @httpProxy IS NOT NULL BEGIN
    EXEC @hresult = sp_OAMethod
        @obj,
        'setProxy',
        NULL,
        '2',
        @httpProxy;

    -- ensure that setting the proxy was successful
    IF @hresult != 0 BEGIN
        SET @errorMessage = CONCAT(
            'Failed calling method ''setProxy'' of ',
            @requestObjectType,
            ' (error code ',
            @hresult,
            ')'
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
    'open',
    NULL,
    'GET',
    @bootstrapUri,
    false;

IF @hresult != 0 BEGIN
    SET @errorMessage = CONCAT(
        'Failed calling method ''open'' of ',
        @requestObjectType,
        ' (error code ',
        @hresult,
        ')'
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
    'send',
    NULL,
    '';
IF @hresult != 0 BEGIN
    SET @errorMessage = CONCAT(
        'Failed calling method ''send'' of ',
        @requestObjectType,
        ' (error code ',
        @hresult,
        ')'
    );

    EXEC sp_OADestroy
        @obj;

    THROW
        50004,
        @errorMessage,
        1;
END;

-- get the results from the HTTP request and ensure that the call was successful
DECLARE @results NVARCHAR(MAX);
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
    'responseText';
IF @hresult != 0 BEGIN
    SET @errorMessage = CONCAT(
        'Failed calling method ''responseText'' of ',
        @requestObjectType,
        ' (error code ',
        @hresult,
        ')'
    );

    EXEC sp_OADestroy
        @obj;

    THROW
        50005,
        @errorMessage,
        1;
END;
SELECT
	@results = [ResultField]
FROM
	#tblResults;
PRINT @results;

-- destroy the request object as we have the resultant Bootstrap procedure
EXEC sp_OADestroy
    @obj;

-- execute the results and create the Bootstrap procedure
EXEC sp_executesql
    @results;

-- check if the Bootstrap procedure was actually created
IF (
    SELECT
        COUNT(*)
    FROM
        INFORMATION_SCHEMA.ROUTINES
    WHERE
        [SPECIFIC_SCHEMA] = 'Pacify'
        AND [SPECIFIC_NAME] = 'Bootstrap'
) = 0 BEGIN
    SET @errorMessage = 'Pacify.Bootstrap procedure was not created';

    THROW
        50006,
        @errorMessage,
        1;
END;

-- finally, execute the Bootstrap procedure
EXEC Pacify.Bootstrap;
