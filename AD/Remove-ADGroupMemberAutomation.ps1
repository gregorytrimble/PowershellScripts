####################### AD Group Removal Automation ################################
#  
#   Created by Greg Trimble
#   Code provided AS IS
#
#
<# 
    .SYNOPSIS
    Automates group membership removals from SQL View created by data warehouse business rules.

    .DESCRIPTION
    This sript removes AD users from groups that they should not be members of, defined in a SQL View
    
    .PARAMETER SQLInstance
    Specifies the SQL instance path.

    .PARAMETER DBName
    Specifies the database name where the view is located.

    .PARAMETER GroupRemoveView
    Specifies the view that contains SamAccountName and GroupName rows that need removals made.

    .PARAMETER InstanceSchema
    Specifies the schema name for the view.

    .PARAMETER WhatIf
    To be run without any arguments. Will output the resulting changes that will be made if the script is run normally.

    .INPUTS
    No inputs can be piped into "Remove-ADGroupMemberAutomation.ps1"

    .OUTPUTS
    Exports a CSV file of changes made, with the verbose flag set on Remove-ADGroupMember, result of group removals will also be shown.

    .EXAMPLE
    .\Remove-ADGroupMemberAutomation.ps1

    .EXAMPLE
    .\Remove-ADGroupMemberAutomation.ps1 -WhatIf

    .EXAMPLE
    .\Remove-ADGroupMemberAutomation.ps1 -SQLInstance <SQLInstanceName> -DBName <DBName> -InstanceSchema <schema> -GroupRemoveView <view>

#>

param(
    [string]$SQLInstance,
    [string]$DBName,
    [string]$GroupRemoveView,
    [string]$InstanceSchema,    
    [switch]$WhatIf
)


Import-Module ActiveDirectory
Import-Module SqlServer

#Gather rows from SQL View ADUserShouldBeRemovedFromGroupAutomationVw, add user to group that has been specified and log result

$dbConnection = New-Object System.Data.SqlClient.SqlConnection
$dbConnection.ConnectionString = "Data Source=$SQLInstance; Database=$DBName; Integrated Security=True"

$runtime = (Get-Date -Format "MM-dd-yyyy_HH-mm")

$result = @()
$grouplist = @()

function Test-SqlInstance
{
    [OutputType([bool])]
    param
    (
        [parameter(Mandatory=$true)]$ConnectionString
    )
    try
    {
        $SQLInstance = New-Object System.Data.sqlClient.SqlConnection $dbConnection.ConnectionString;
        $SQLInstance.Open();
        $SQLInstance.Close();
        return $true
    }
    catch
    {
        return $false
    }
}


if (Test-SqlInstance($dbConnection.ConnectionString))
{
    if (Read-SqlViewData -ServerInstance $SQLInstance -DatabaseName $DBName -ViewName $GroupRemoveView -SchemaName $InstanceSchema -TopN 1)
    {        
        $RemoveFromGroup = Read-SqlViewData -ServerInstance $SQLInstance -DatabaseName $DBName -ViewName $GroupRemoveView -SchemaName $InstanceSchema
        foreach ($row in $RemoveFromGroup)
        {            
            try
            {
                $ADGroup = (Get-ADGroup -Identity $row.SamAccountName)
                
                if($WhatIf)
                {
                    Write-Host "Will remove " $row.ADUserName " from " $ADGroup.SamAccountname
                }
                else
                {                       
                    Remove-ADGroupMember -Identity $ADGroup.Samaccountname -Members $row.ADUserName -Verbose -Confirm:$false                    
                    if ((Get-ADGroupMember -Identity $ADGroup.Samaccountname).samaccountname -contains $row.ADUserName)
                    {
                        #Removal failed. Return error                        
                        Write-Error "Removal failed for user $row.ADUserName for $ADGroup.SamAccountName"
                    }
                    else
                    {
                        $result += @([pscustomobject]@{GroupName=$ADGroup.Name;UserName=$row.ADUserName})                        
                    }                    
                }
            }
            catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
            {
                Write-Warning "$row.ADGroupName group does not exist"
            }

        }
    }
}
else
{
    Write-Error "DB instance $SQLInstance is not reachable"
}

if ($result -ne $null)
{
    #Note: service account will need access to write to this location. Also, will need a separate process to cleanup old files.
    #Output file could be used as a rollback, but data is also stored in the database.
    $OutputFile = "ADGroupAddAutomation\ADUserRemovedFromGroup" + $runtime + ".csv"    
    $result | Export-Csv -Path $OutputFile
}


# Email results to interested parties

if ($OutputFile)
{    
    $smtpServer = "mail.yourdomain.com"
    $msg = new-object Net.Mail.MailMessage
    $smtp = new-object Net.Mail.SmtpClient($smtpServer)
    $file = $outputfile
    $att = new-object Net.Mail.Attachment($file)
    $msg.From = "noreply@yourdomain.com"

    #Add or remove users/distribution lists here    
    $msg.To.Add("someaddress@yourdomain.com")
    $msg.subject = "AD Group members removal script report run at $runtime"
    $msg.body = "Attached is a report of group removals from view $GroupAddView `
    A copy of this file is stored at $OutputFile"
    $msg.Attachments.Add($att)
    $smtp.Send($msg)
    $att.Dispose()    
}