param (
	# Default source and destination is DNSRoot from Get-ADDomain
	[string]$SourceServer = (Get-ADDomain | Select-Object DNSRoot | Out-String),
	[string]$SourcePath,
	[string]$DestinationServer = (Get-ADDomain | Select-Object DNSRoot | Out-String),
	[string]$DestinationPath,
	[switch]$ShowConflicts,
	[switch]$Verbose
)

$WhoAmI = "Migrate ADGroups"
$Version = "1.0"
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
	write-host "-SourceServer <string> -SourcePath <string> -DestinationServer <string> -DestinationPath <string> [-ShowConflicts] [-Verbose]`n" -ForegroundColor Gray
	
	write-host "PARAMETERS: "
	write-host "*" -ForegroundColor Red -NoNewLine 
	write-host " -SourceServer `tThe Name.ParentDomain of the AD server you're migrating from."
	write-host "*" -ForegroundColor Red -NoNewLine 
	write-host " -SourcePath `t`tThe DistinguishedName of the OU where the AD Groups you want to migrate are."
	write-host "*" -ForegroundColor Red -NoNewLine 
	write-host " -DestinationServer `tThe Name.ParentDomain of the AD server you're migrating to."
	write-host "*" -ForegroundColor Red -NoNewLine 
	write-host " -DestinationPath `tThe DistinguishedName of the OU where you want to migrate the AD Groups in the SourcePath to."
	write-host "  -ShowConflicts `tWill give you a table of migration conflicts that ocurred during migration."
	write-host "  -Verbose `t`tOutputs details of every group during migration.`n"
	write-host "`t*required" -ForegroundColor Red
	write-host "`n========================================================" -ForegroundColor Yellow
	exit
}

if($SourcePath -eq "" -or $DestinationPath -eq "") {
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
		write-host "Found Source Group: $GroupName"
		
		$GroupMigrated = 0
		
		# Does this group exist on the destination?
		if(Get-ADGroup -Filter {Name -eq $GroupName} -Server $DestinationServer -SearchBase $DestinationPath) {
			write-host "> This group already exists on the destination. Skipping."
			$GroupMigrated = 1
		} else {
			# Create the group on the destination
			try {
				New-ADGroup -Server $DestinationServer -Path $DestinationPath -Name $GroupName -GroupScope $Group.GroupScope -GroupCategory $Group.GroupCategory
				write-host "> Creating group on destination... "
			} catch {
				# Give helpful feedback if there is a problem where an AD Account exists on the destination server that is the same name as 
				# the AD Group from the source server. This is such a headache if you aren't prepared for this during migration.
				$ErrorMessage = $_.Exception.Message
				if($ErrorMessage -like "*group already exists*") { 
					$MigrationConflicts.add($GroupName, $Conflict.GroupAlreadyExists)
					#write-host "`nWARNING:`n" -NoNewLine -ForegroundColor Red 
					#write-host "          There is already a group with the name $GroupName on the destination server...
#		  BUT that account is not in the migrated group folder--it just exists somewhere on your destination server.
#          Therefore, the existing group on the destination server with the name $GroupName is going to be used to 
#		  migrate over all the accounts listed in the same group on the source server.
#          IF YOU DO NOT WANT TO MIGRATE THAT GROUP until you have time to figure out what is going on,
#          BAIL OUT of this script immediately by pressing CTRL+C.`n`nOtherwise, press any key to continue."
#					$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
				}
				
				if($ErrorMessage -like "*account already exists*") {
					$MigrationConflicts.add($GroupName, $Conflict.AccountAlreadyExists)
#					write-host "`nWARNING:`n" -NoNewLine -ForegroundColor Red
#					write-host "          While trying to migrate over the group ""$GroupName"" from the source server,
#it turns out there is an account on the destination server with that exact same name. You'll need to fix this, as you
#cannot have an account and group in AD with the same name. I recommend bailing out of this script (CTRL+C), otherwise,
#hit any key to continue."
#					$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
				}
				write-host "Conflict Encountered. Could not create group $GroupName because: $ErrorMessage"
			} 	
		}
		
		# Get all users in this source group
		# Add them to destination group 
		
		#New-AdGroup -Server "campus.network.bcc" -Path $DestinationOU -Name $Record.Name -GroupScope $Record.GroupScope -GroupCategory $Record.GroupCategory	
	}
}

if($ShowConflicts) {

	$MigrationConflicts | Format-Table -AutoSize



}
# At the end, let's write out the migration conflicts if that's what we want.