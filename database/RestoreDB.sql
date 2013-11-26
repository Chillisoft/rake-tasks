USE MASTER
GO

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[$(database)]') AND type in (N'U'))
  ALTER DATABASE $(database) SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
 
create table #backupInformation (LogicalName nvarchar(128),
PhysicalName nvarchar(260),
Type char(1),
FileGroupName nvarchar(128) ,
Size numeric(20,0) ,
MaxSize numeric(20,0),
FileId bigint,
CreateLSN numeric(25,0),
DropLSN numeric(25,0),
UniqueId uniqueidentifier,
ReadOnlyLSN numeric(25,0),
ReadWriteLSN numeric(25,0),
BackupSizeInBytes bigint,
SourceBlockSize int,
FileGroupId int,
LogGroupGUID uniqueidentifier,
DifferentialBaseLSN numeric(25,0),
DifferentialBaseGUID uniqueidentifier,
IsReadOnly bit, IsPresent bit, TDEThumbprint varbinary(32) )
 
insert into #backupInformation exec('restore filelistonly from disk = ''$(backupfilename)''')
 
DECLARE @logicalNameD varchar(255);
DECLARE @logicalNameL varchar(255);

select top 1 @logicalNameD = LogicalName from #backupInformation where Type = 'D';
select top 1 @logicalNameL = LogicalName from #backupInformation where Type = 'L';
 
DROP TABLE #backupInformation 

RESTORE DATABASE $(database)
FROM DISK = '$(backupfilename)'
WITH REPLACE,
MOVE @logicalNameD TO '$(SQLDataFileFolder)\$(database).mdf',
MOVE @logicalNameL TO '$(SQLDataFileFolder)\$(database).ldf', replace
GO
