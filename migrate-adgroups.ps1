param (
	# Default source and destination is DNSRoot from Get-ADDomain
	[string]$SourceServer = (Get-ADDomain | Select-Object DNSRoot | Out-String),
	[string]$SourcePath,
	[string]$DestinationServer = (Get-ADDomain | Select-Object DNSRoot | Out-String),
	[string]$DestinationPath,
	[switch]$ShowConflicts,
	[switch]$Verbose,
	[string]$UsersServer = (Get-ADDomain | Select-Object DNSRoot | Out-String),
	[string]$FixConflictsByAdding
)

$WhoAmI = "Migrate ADGroups"
$Version = "1.1"
$WhoWroteMe = "Jesse Lawson <jesse@lawsonry.com>"

# This will be used during migration if there are any groups or accounts that already exist on the destination server
$MigrationConflicts = @{}
$Conflict = @{}
$Conflict.GroupAlreadyExists = "This group already exists on the destination server."
$Conflict.AccountAlreadyExists = "An account with this name exists on the destination server, preventing a group with the same name being migrated."

function Show-HelpScreen {
	write-host "`n========================================================" -ForegroundColor Yellow
	write-host "$WhoAmI (v$Version) by $WhoWroteMe`n"
	write-host "USAGE:"
	write-host ".\migrate-adgroups.ps1 " -ForegroundColor Green -NoNewLine
	write-host "-SourceServer <string> -SourcePath <string> -DestinationServer <string> -DestinationPath <string> -UsersServer <string> [-ShowConflicts] [-FixConflictsByAdding <string>] [-Verbose]`n" -ForegroundColor Gray
	
	write-host "PARAMETERS: "
	write-host "*" -ForegroundColor Red -NoNewLine 
	write-host "-SourceServer `t`tThe Name.ParentDomain of the AD server you're migrating from."
	write-host "*" -ForegroundColor Red -NoNewLine 
	write-host "-SourcePath `t`tThe DistinguishedName of the OU where the AD Groups you want to migrate are."
	write-host "*" -ForegroundColor Red -NoNewLine 
	write-host "-DestinationServer `tThe Name.ParentDomain of the AD server you're migrating to."
	write-host "*" -ForegroundColor Red -NoNewLine 
	write-host "-DestinationPath `tThe DistinguishedName of the OU where you want to migrate the AD Groups in the SourcePath to."
	write-host "*" -ForegroundColor Red -NoNewLine 
	write-host "-UsersServer `t`tSpecify the AD server where the user accounts exist."
	write-host " -FixConflictsByAdding `tIf there's a group conflict, fix it by creating a new group with <string> appended."
	write-host " -ShowConflicts `tWill give you a table (console + txt file) of migration conflicts that ocurred during migration."
	write-host " -Verbose `t`tOutputs details of every group during migration.`n"
	write-host "`t*required" -ForegroundColor Red
	write-host "`n========================================================" -ForegroundColor Yellow
	exit
}

if($SourcePath -eq "" -or $DestinationPath -eq "" -or $SourceServer -eq "" -or $DestinationServer -eq "" -or $UsersServer -eq "") {
	Show-HelpScreen
	exit
}

# This script will migrate all CNs from $SourcePath to $DestinationPath.
	
# Get list of all CNs from source
$SourceGroups = $null

try {
	$SourceGroups = Get-ADGroup -Filter * -Server $SourceServer -SearchBase $SourcePath
} 
catch {
	$ErrorMessage = $_.Exception.Message
	write-host "Could not get groups : $ErrorMessage"
}
finally {
	if($SourceGroups -eq $null) {
		write-host "Could not get source groups. Bailing out."
		exit
	}
}

# Loop through $SourceGroups and see if they exist on the destination server. If not, create them. 
foreach ( $Group in $SourceGroups ) {
	if($Group.objectClass -eq "group") {
		$GroupName = $Group.Name
		if($Verbose) { write-host "Migrating $GroupName from source to destination... " -NoNewLine }
		
		$GroupMigrated = 0
		
		# Does this group exist on the destination?
		if(Get-ADGroup -Filter {Name -eq $GroupName} -Server $DestinationServer -SearchBase $DestinationPath) {
			if($Verbose) { write-host "SKIPPING. Already exists on destination server." }
			$GroupMigrated = 1
		} else {
			# Create the group on the destination
			try {
				New-ADGroup -Server $DestinationServer -Path $DestinationPath -Name $GroupName -GroupScope $Group.GroupScope -GroupCategory $Group.GroupCategory
			} catch {
				# Give helpful feedback if there is a problem where an AD Account exists on the destination server that is the same name as 
				# the AD Group from the source server. This is such a headache if you aren't prepared for this during migration.
				$ErrorMessage = $_.Exception.Message
				if($ErrorMessage -like "*group already exists*") {
					# Still count this group as migrated, since an existing group is still something we can add people to.
					$GroupMigrated = 1
					$MigrationConflicts.add($GroupName, $Conflict.GroupAlreadyExists)
					if($Verbose) {
						write-host "SKIPPED WITH CAUSE:`n" -ForegroundColor Red
						write-host "> There is already a group with the name $GroupName on the destination server...
  BUT that account is not in the migrated group folder--it just exists somewhere on your destination server.
  Therefore, the existing group on the destination server with the name $GroupName is going to be used to 
  migrate over all the accounts listed in the same group on the source server."
#					$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
					}
				}
				
				if($ErrorMessage -like "*account already exists*") {
					# Flag this group as a special case to deal with IF we have set the -FixConflictsByAdding flag
					$GroupMigrated = 2
					$MigrationConflicts.add($GroupName, $Conflict.AccountAlreadyExists)
					if($Verbose) {
						if($FixConflictsByAdding) {
							write-host "MARKED:`n" -NoNewLine -ForegroundColor Red
							write-host "> While trying to migrate over the group ""$GroupName"" from the source server,
  it turns out there is an account on the destination server with that exact same name. However, you have indicated to
  fix this conflict by migrating ""$GroupName"" to ""$GroupName$FixConflictsByAdding""."
						} else {
							write-host "FAILED:`n" -NoNewLine -ForegroundColor Red
							write-host "> While trying to migrate over the group ""$GroupName"" from the source server,
  it turns out there is an account on the destination server with that exact same name. You'll need to fix this, as you
  cannot have an account and group in AD with the same name. This group will be skipped during this migration."
						}
						
#					$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
					}
				}
				if($Verbose) { write-host "Conflict Encountered. Could not create group $GroupName because: $ErrorMessage" }
			} # end try-catch 
			 	
		}
		
		# Check for the -FixConflictsByAdding. If we have it set, we'll try to recreate this group as a new one, and then we'll migrate all users
		# from $Group to $DestinationGroup
		$DestinationGroup = $null
		
		if($FixConflictsByAdding) {
			# Only worry about this group if it was flagged from the "account already exists" error block above
			if($GroupMigrated -eq 2) {
				# Create a new group on the destination server whose name will be "$Group.Name"+"$FixConflictsByAdding"
				$NewGroupName = $Group.Name+$FixConflictsByAdding 
				
				if($Verbose) { write-host "> Creating new destination group $NewGroupName... " -NoNewLine}
				
				# Check if it already exists, for sadists who manually created the conflict amelioration groups by hand (like me)
				if(Get-ADGroup -Filter {Name -eq $NewGroupName} -Server $DestinationServer -SearchBase $DestinationPath) {
					if($Verbose) { write-host "SKIPPING. Already exists."}
					
					$DestinationGroup = Get-ADGroup -Filter {Name -eq $NewGroupName} -Server $DestinationServer -SearchBase $DestinationPath
					$GroupMigrated = 1
					
					# Override any variables from the old group name 
					$GroupName = $NewGroupName
				} else {
				
					try {
						New-ADGroup -Server $DestinationServer -Path $DestinationPath -Name $NewGroupName -GroupScope $Group.GroupScope -GroupCategory $Group.GroupCategory
					} catch {
						$ErrorMessage = $_.Exception.Message 
						write-host "FAILED.`nERROR: $ErrorMessage"
					} finally {
						# If the destination group exists, let's mark this group as okay to migrate 
						if(Get-ADGroup -Filter {Name -eq $NewGroupName} -Server $DestinationServer -SearchBase $DestinationPath) {
							
							$DestinationGroup = Get-ADGroup -Filter {Name -eq $NewGroupName} -Server $DestinationServer -SearchBase $DestinationPath
							# Hooray! It worked!
							$GroupMigrated = 1
							
							# Override any variables from the old group name 
							$GroupName = $NewGroupName
						}
					}
				}
			}
		}
		
		# If this group was successfully migrated OR already exists on the destination server, 
		# let's get all the users from the source and migrate them to the destination.
		if($GroupMigrated -eq 1) {
			
			if($Verbose) { write-host "> Getting users in group $GroupName... " -NoNewLine}
			
			try {
				$Users = $Group | Get-AdGroupMember -Server $SourceServer
			} catch {
				$ErrorMessage = $_.Exception.Message
				write-host "FAILED.`nSomething went wrong trying to get the users in $GroupName!`nERROR: $ErrorMessage"
			}
			
			# For each user, add them to the destination group
			if($Users -eq $null) {
				if($Verbose) { write-host "FAILED?`nWARNING: No users were found in this group. Is this expected?" }
			} else {
				if($Verbose) { write-host "DONE." }
				foreach($User in $Users) {
					$UserName = $User.SamAccountName
					
					if($Verbose) { write-host ">> Migrating User $UserName to group $GroupName... " -NoNewLine }
					
					# Add that user account to the group. Of course this is assuming that the destination server has the users 
					$TheUser = Get-AdUser -Filter { SamAccountName -eq $UserName } -server $UsersServer
					#$TargetGroup = Get-AdGroup -Filter { Name -eq $GroupName } -server $DestinationServer
					
					# Add user to group 
					if(Get-ADUser -Identity $UserName -Server $UsersServer) {
						# This member has already been migrated; skip.
						if($Verbose) { write-host "SKIPPED. Already migrated." }
					} else {
						try {
							Add-ADGroupMember -Identity $DestinationGroup -Members $TheUser -Server $UsersServer
						} catch {
							$ErrorMessage = $_.Exception.Message
							write-host "ERROR: $ErrorMessage"
						} finally {
							# Check again
							if(Get-ADUser -Identity $UserName -Server $UsersServer) {
								if($Verbose) { write-host "DONE." }
							}
						}
					}
				}
			}	
		}
	}
}

if($ShowConflicts) {
	$MigrationConflicts | Out-File migration-conflicts.txt -Encoding UTF8
	$MigrationConflicts | Format-Table -AutoSize
}
# At the end, let's write out the migration conflicts if that's what we want.