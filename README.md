# Migrate ADGroups

A simple PS CLI tool to migrate one set of Active Directory group containers from one OU folder to another. 

## Quickstart

### Parameters

| Param              | Type                  | Example                       | Default                                              |
|:-------------------|:----------------------|:-----------------------------------------------------------------|:------------------|
| -SourceServer      | String, Optional      | `-SourceServer "example.com"`                                    | (none; mandatory) |
| -SourcePath        | String, Mandatory     | `-SourcePath "OU=Folder,OU=AnotherFolder,DC=example,DC=com`      | (none; mandatory) |
| -DestinationServer | String, Optional      | `-DestinationServer "example.com"`                               | (none; mandatory) |
| -DestinationPath   | String, Mandatory     | `-DestinationPath "OU=Folder,OU=AnotherFolder,DC=example,DC=com` | (none; mandatory) |
| -UsersServer       | String, Mandatory     | `-UsersServer "example.com"`                                     | (none; mandatory) |
| -ShowConflicts     | Switch, Optional      | `-ShowConflicts`                                                 | off               |
| -Verbose           | Switch, Optional      | `-Verbose`                                                       | off               |

### Example

```powershell
PS C:\Jesse> .\migrate-adgroups.ps1 -SourceServer "source.abc" -SourcePath "OU=SourceInnerFolder,OU=SourceOuterFolder,DC=source,DC=abc" -DestinationServer "destination.xyz" "OU=DestinationInnerFolder,OU=DestinationOuterFolder,DC=destination,DC=xyz" -UsersServer "destination.xyz"
```

## Usage

The following is just an example.

Let's say you have a bunch of AD Groups on `garage.com` and I want to move them over to `kitchen.com`. The groups on the source folder, garage, are inside specific folders (like this: `SourceOuterFolder/SourceInnerFolder/<group>`) and I want them to go to the destination folder in the same way (i.e., `DestinationOuterFolder/DestinationInnerFolder/<group>`).

So as an example, if I were to open AD Users and Computers, I might see something like this:

```
Active Directory Users and Computers [dc.garage.com]
garage.com
- SourceOuterFolder
- - SourceInnerFolder 
- - - Group A
- - - Group B
- - - Group N
```

What I want is to copy everything from `SourceInnerFolder` to an OU on a destination server that I am calling `DestinationInnerFolder`. I want 1) all groups copied over if they don't exist already, and 2) all users from the source group added to the new groups at the destination. 

So the destination should look something like this:

```
Active Directory Users and Computers [dc.kitchen.com]
kitchen.com
- DestinationOuterFolder
- - DestinationInnerFolder
- - - Group A
- - - Group B
- - - Group C
```

Here's how I would do that:

```powershell
PS C:\Jesse> .\migrate-adgroups.ps1 -SourceServer "garage.com" -SourcePath "OU=SourceInnerFolder,OU=SourceOuterFolder,DC=garage,DC=com" -DestinationServer "kitchen.com" "OU=DestinationInnerFolder,OU=DestinationOuterFolder,DC=kitchen,DC=com"
```

### How does this work

The path variables (that you see for the `-SourceServer` and `-DestinationServer` parameters) are the DistinguishedNames minus the `CN=*` part. An Active Directory Object's distinguished name is basically like an address mapping straight to that AD Object. 

For example, if I had the following in AD Users and Groups:

```
Active Directory Users and Computers [dc.kitchen.com]
kitchen.com
- Appliances
- - Food and Beverage
- - - Toaster
- - - Fridge
- - - Oven
```

... then I could give you the path to each of the groups in the `Food and Beverage` OU by looking up their distinguished names:

| AD Group | DistinguishedName |
|:---------|:------------------|
| Toaster  | CN=Toaster,OU=Food and Beverage,OU=Appliances,DC=kitchen,DC=com |
| Fridge   | CN=Fridge,OU=Food and Beverage,OU=Appliances,DC=kitchen,DC=com |
| Oven     | CN=Oven,OU=Food and Beverage,OU=Appliances,DC=kitchen,DC=com |

So, when you pass a path variable, you are basically saying "use this as the second part of the distinguishedName," where the first part will be "CN=<groupname>."

When using `migrate-adgroups`, you want to pass the source Path as the OU hierarchy where all the CN's (the groups) live. You want to do the **same thing** for the source path. 

### Important Considerations 

* A group existing on your destination server but not necessarily in your destination path will trigger a merge conflict, BUT that group will be used for the migration.

* The script will straight up ignore any groups from the source if there is an AD account with the same name on the target. You'll have to manually move these over (sorry). Look on the bright side, though: at least you get a handy `merge-conflicts.txt` file that gives you a checklist of which ones you need to worry about!


## Optional Flags

### -ShowConflicts

If you enable the ShowConflicts flag, you'll get a table at the end of the migration that shows you all of the migration conflicts. There are really only two conflicts that can occur: either A) your group name already exists as a group on the destination server, or B) your group name already exists as an account on the destination server. The former type of conflicts are easily ignored, but the latter are ones that will cause headaches. 

Example output: 

```
Name 			Value
My Group		An account with this name already exists in the destination server, preventing a group with the same name from being migrated.
Some Group		This group already exists on the destination server.
Another Group	This group already exists on the destination server.
One Group		An account with this name already exists in the destination server, preventing a group with the same name from being migrated.
Two Group		This group already exists on the destination server.
Red Group		An account with this name already exists in the destination server, preventing a group with the same name from being migrated.
Blue Group 		This group already exists on the destination server.
```
