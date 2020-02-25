####################### Remove-VMMedia.ps1 ################################
#
#   Created by Greg Trimble
#   Code provided AS IS
#  
<# 
    .SYNOPSIS
    Detaches vmguest.iso (guest integrations) attached to any HyperV VM's

    .DESCRIPTION
    This script removes the vmguest.iso media from any HyperV VM's from specified hosts
    
    .INPUTS
    No inputs can be piped into "Remove-VMMedia.ps1"

    .OUTPUTS
    No output is created by Remove-VMMedia.ps1

    .EXAMPLE
    .\Remove-VMMedia.ps1

#>

#Specify list of hosts to check for attached vmguest.iso
$hostlist = ("")

foreach ($vmhost in $hostlist)
{    
    $hostvmlist = Get-VM -ComputerName $vmhost
    foreach ($vm in $hostvmlist)
    {
        $vmdvdinfo = (Get-VMDvdDrive -VMName $vm.Name -ComputerName $vmhost)
        if (($vmdvdinfo.DVDMediaType -eq "ISO") -and ($vmdvdinfo.Path -like "*vmguest.iso*" ))
        {
            $vmdvdinfo
            Set-VMDvdDrive -VMName $vm.Name -ComputerName $vmhost -Path $null
        }        
    }
}