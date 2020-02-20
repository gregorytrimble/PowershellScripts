####################### Get-ADDenyACL.ps1 ################################
#
#   Created by Greg Trimble
#   Code provided AS IS
#
<# 
    .SYNOPSIS
    Gets denied ACL's in domain specified

    .DESCRIPTION
    This sript gets AD users who have deny permissions configured on AD DS OU's and objects, and outputs the results. Only non-inherited results are returned.
    
    .PARAMETER ADDSName
    Specifies the domain 

    .PARAMETER WhatIf
    To be run without any arguments. Will output the resulting changes that will be made if the script is run normally.

    .INPUTS
    No inputs can be piped into "Add-ADGroupMemberAutomation.ps1"

    .OUTPUTS
    Exports a CSV file 

    .EXAMPLE
    .\Get-ADDentyACL.ps1 -ADDSName "AD:DC=contoso,DC=com"

#>

param(
    [string]$ADDSName = "AD:DC=contoso,DC=com",
    [string]$OutFile = "NonInheritedDeniedACL.csv"
)
$DN = $ADDSName

$AllOU = Get-ChildItem -Path $DN -Recurse

foreach ($ADObj in $AllOU)
{
    $ObjPath = "AD:" + $ADObj
    $DeniedObj = (Get-Acl -Path $ObjPath | select -ExpandProperty access | Where-Object {($_.accesscontroltype -eq "deny") -and ($_.isinherited -eq $false)})
    if ($DeniedObj)
    {
        $DeniedObj | Add-Member -MemberType NoteProperty "ObjectName" -Value $ADObj
        $results += $DeniedObj
        $DeniedObj
    }
}

$results | Export-Csv -Path $OutFile