# Migrate ADGroups

A simple PS CLI tool to migrate one set of Active Directory group containers from one OU folder to another. 

## Quickstart

### Parameters

| Param | Type | Example | Default | 
|:-------------------|:------------|:------------------------------|:---------------------------------------|
| -SourceServer      | String      | `-SourceServer "example.com"` | `Get-ADDomain | Select-Object DNSRoot` |
| -SourcePath        | String      | `-SourcePath "OU=Folder,OU=AnotherFolder,DC=example,DC=com` | (none; mandatory) |
| -DestinationServer | String      | `-DestinationServer "example.com"` | `Get-ADDomain | Select-Object DNSRoot` |
| -DestinationPath   | String      | `-DestinationPath "OU=Folder,OU=AnotherFolder,DC=example,DC=com` | (none; mandatory) |

### Example

```powershell
PS C:\Jesse> .\migrate-adgroups.ps1 -SourceServer "source.abc" -SourcePath "OU=SourceInnerFolder,OU=SourceOuterFolder,DC=source,DC=abc" -DestinationServer "destination.xyz" "OU=DestinationInnerFolder,OU=DestinationOuterFolder,DC=destination,DC=xyz"
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

