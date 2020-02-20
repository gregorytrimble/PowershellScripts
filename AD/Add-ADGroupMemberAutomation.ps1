####################### AD Group Addition Automation ################################
#
#   Created by Greg Trimble
#   Code provided AS IS
#
<# 
    .SYNOPSIS
    Automates group membership additions from SQL View created by data warehouse business rules.

    .DESCRIPTION
    This sript adds AD users to groups that they should be members of, defined in a SQL view. 
    
    .PARAMETER SQLInstance
    Specifies the SQL instance path

    .PARAMETER DBName
    Specifies the database name where the view is located.

    .PARAMETER GroupAddView
    Specifies the view that contains SamAccountName and GroupName rows that need additions made.

    .PARAMETER InstanceSchema
    Specifies the schema name for the view

    .PARAMETER WhatIf
    To be run without any arguments. Will output the resulting changes that will be made if the script is run normally.

    .INPUTS
    No inputs can be piped into "Add-ADGroupMemberAutomation.ps1"

    .OUTPUTS
    Exports a CSV file of changes made, with the verbose flag set on Add-ADGroupMember, result of group adds will also be shown.

    .EXAMPLE
    .\Add-ADGroupMemberAutomation.ps1

    .EXAMPLE
    .\Add-ADGroupMemberAutomation.ps1 -WhatIf

    .EXAMPLE
    .\Add-ADGroupMemberAutomation.ps1 -SQLInstance <SQLInstanceName> -DBName <DBName> -InstanceSchema <schema> -GroupAddView <view>

#>

param(
    [string]$SQLInstance,
    [string]$DBName,
    [string]$GroupAddView,
    [string]$InstanceSchema,
    [string]$User,
    [string]$password,
    [switch]$WhatIf
)


Import-Module ActiveDirectory
Import-Module SqlServer

#Gather rows from SQL View ADUserShouldBeAddedToGroupAutomationVw, add user to group that has been specified and log result

$Username = $User | ConvertTo-SecureString -AsPlainText -Force
$PW = $password | ConvertTo-SecureString -AsPlainText -Force
$creds = New-Object system.management.automation.pscredential($Username,$PW)


$dbConnection = New-Object System.Data.SqlClient.SqlConnection
$dbConnection.ConnectionString = "Data Source=$SQLInstance; Database=$DBName; Integrated Security=True"

$runtime = (Get-Date -Format "MM-dd-yyyy_HH-mm")

$result = @()
$grouplist = @()

#Used to verify SQL instance is up and reachable
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
    if (Read-SqlViewData -ServerInstance $SQLInstance -DatabaseName $DBName -ViewName $GroupAddView -SchemaName $InstanceSchema -TopN 1)
    {        
        $AddToGroup = Read-SqlViewData -ServerInstance $SQLInstance -DatabaseName $DBName -ViewName $GroupAddView -SchemaName $InstanceSchema
        foreach ($row in $AddToGroup)
        {            
            try
            {
                $ADGroup = (Get-ADGroup -Identity $row.SamAccountName -Credential $creds)
                
                if($WhatIf)
                {
                    Write-Host "Will add " $row.ADUserName " to " $ADGroup.SamAccountname
                }
                else
                {   
                    Add-ADGroupMember -Identity $ADGroup.Samaccountname -Credential $creds -Members $row.ADUserName -Verbose
                    if ((Get-ADGroupMember -Identity $ADGroup.Samaccountname -Credential $creds).samaccountname -contains $row.ADUserName)
                    {                        
                        $result += @([pscustomobject]@{GroupName=$ADGroup.Name;UserName=$row.ADUserName})                        
                    }
                    else
                    {
                        Write-Error "Failed to add user $row.ADUserName to $ADGroup.SamaccountName"
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
    #Output file could be used as a rollback, but data is also stored in the database. Customize path as desired.
    $OutputFile = "ADGroupAddAutomation\ADUserAddedToGroup" + $runtime + ".csv"        
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
    $msg.subject = "AD Group members addition script report run at $runtime"
    $msg.body = "Attached is a report of group additions from view $GroupAddView `
    A copy of this file is stored at $OutputFile"
    $msg.Attachments.Add($att)
    $smtp.Send($msg)
    $att.Dispose()    
}