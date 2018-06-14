# Migrate ADGroups

A simple PS CLI tool to migrate one set of Active Directory group containers from one OU folder to another. 

## Usage

Let's say you have a bunch of AD Groups on `garage.com` 

```powershell
PS C:\Jesse> .\migrate-adgroups.ps1 -SourceServer "garage.com" -SourcePath "OU=GroupsToMigrate,OU=FolderWithGroups,DC=garage,DC=com" -DestinationServer "OU=TheGroups,OU=FolderWithGroups,DC=kitchen,DC=com"