####################### Get-LoggedOnUserSession.ps1 ################################
#
#   Created by Greg Trimble
#   Code provided AS IS
#
<# 
    .SYNOPSIS
    Gets computers that a user is currently logged on to for a given set of HyperV host objects
    
    .DESCRIPTION
    Queries explorer.exe process via a WMI call to each computer object specified.
        
    .PARAMETER User
    Specified user to search for logins for    

    .PARAMETER ResultFile
    Output saved to this path
    
    .INPUTS
    No inputs can be piped into "Get-LoggedOnVmUserSessions.ps1"

    .OUTPUTS
    Outputs results of user sessions to CSV file
    
    .EXAMPLE
    .\Get-LoggedOnUserSession.ps1 -User bob@contoso.com -ResultFile "LoggedOnResults.txt"

    
#>


param(
    [Parameter(Mandatory=$true)][string]$User,
    [Parameter(Mandatory=$true)][string]$ResultFile
)

$EnabledHyperV12R2Servers = (Get-ADComputer -Filter * -SearchBase "OU=HyperV,DC=contoso,DC=com")
$runningvms = @()

foreach ($srv in $EnabledHyperV12R2Servers)
{    
    if (Test-Connection -ComputerName $srv.name -Count 1 -Quiet)
    {
        $runningvms += Get-VM -ComputerName $srv.name | Where-Object {$_.state -eq "running"} | select name
    }
}
$results = @()
foreach ($vm in $runningvms)
{
    if ((Test-Connection -ComputerName $vm.name -Count 1 -ErrorAction SilentlyContinue) -and (Get-ADComputer -Identity $vm.name -ErrorAction SilentlyContinue))
    {     
        #Write-Host $vm.name

        $ExplorerUsrs = (Get-WmiObject -ComputerName $vm.name -Class win32_process | where {$_.processname -like "explorer.exe"})        
        if($ExplorerUsrs)
        {
            if($ExplorerUsrs.GetOwner().User -eq $User)
            {
                $results += ($ExplorerUsrs.GetOwner().User,$vm.name)
            }
        }
    }
}

$results | Export-Csv -Path $ResultFile