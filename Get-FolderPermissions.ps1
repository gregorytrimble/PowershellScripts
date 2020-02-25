####################### Get-FolderPermissions.ps1 ################################
#
#   Created by Greg Trimble
#   Code provided AS IS
#
<# 
    .SYNOPSIS
    Lists ACL's for a given path

    .DESCRIPTION
    Retrieves permissions on path specified, as well as sub-directories of the provided path
        
    .PARAMETER permpath
    Specifies the path to retrieve ACL's on.
    
    .INPUTS
    No inputs can be piped into "Get-FolderPermissions.ps1"

    .OUTPUTS
    No outputs are made.

    .EXAMPLE
    .\Get-FolderPermissions.ps1

#>

param(
    [Parameter(Mandatory=$true)]
    [Alias('Path')]$permpath
)

[Array] $folders = Get-ChildItem -Path $permpath -Force -Recurse -Directory

Write-Host $permpath

Get-Acl -Path $permpath | Format-List -Property AccessToString

foreach ($f in [Array] $folders)
{    
    Convert-Path -LiteralPath $f.pspath    
    Get-Acl -Path (Convert-Path -LiteralPath $f.pspath) | Format-List -Property AccessToString
}
