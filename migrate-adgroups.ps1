
# This script will migrate all CNs from $sourcePath to $destinationPath.

$sourcePath = "OU=ReportServer,OU=Security Groups,OU=IT-S Systems and Users,DC=infosys,DC=bcc" 
$sourceServer = "infosys.bcc"
$destinationPath = "OU=ReportServer,OU=IS,DC=campus,DC=network,DC=bcc" 
$destinationServer = "campus.network.bcc"

# Get list of all CNs from source
$SourceGroups = $null

try {
	$SourceGroups = Get-ADGroup -Filter * -Server $sourceServer -SearchBase $sourcePath
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
		if(Get-ADGroup -Filter {Name -eq $GroupName} -Server $destinationServer -SearchBase $destinationPath) {
			write-host "> This group already exists on the destination. Skipping."
			$GroupMigrated = 1
		} else {
			# Create the group on the destination
			try {
				New-ADGroup -Server $destinationServer -Path $destinationPath -Name $GroupName -GroupScope $Group.GroupScope -GroupCategory $Group.GroupCategory
				write-host "> Creating group on destination... "
			} catch {
				# Give helpful feedback if there is a problem where an AD Account exists on the destination server that is the same name as 
				# the AD Group from the source server. This is such a headache if you aren't prepared for this during migration.
				$ErrorMessage = $_.Exception.Message
				if($ErrorMessage -contains -like "*already exists*") { 
					write-host "WARNING: There is already a group or account with the name $GroupName on the destination server. "
				}
				write-host "ERROR: Could not create group $GroupName : $ErrorMessage"
			} 	
		}
		
		# Get all users in this source group
		# Add them to destination group 
		
		#New-AdGroup -Server "campus.network.bcc" -Path $destinationOU -Name $Record.Name -GroupScope $Record.GroupScope -GroupCategory $Record.GroupCategory	
	}
}