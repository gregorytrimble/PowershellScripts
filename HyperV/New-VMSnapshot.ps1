####################### New-VMSnapshot.ps1 ################################
#
#   Created by Greg Trimble
#   Code provided AS IS
#
<# 
    .SYNOPSIS
    Takes a snapshot for specified VM

    .DESCRIPTION
    This script takes a snapshot on the HyperV host of specified VM.
    Only the VM name is required for a parameter, and the host is determined automatically.
    
    .PARAMETER VMName
    Specifies the VM name

    .PARAMETER AdditionalNotifyEmail
    Specifies additional email addresses to send notification to.

    .PARAMETER OutputFile
    Specifies the output file location where the CSV results will be written.

    .PARAMETER OfflineVHDCopy
    Specifies whether an offline VHD copy will be made. VM will be shut down, and VHDX file(s) copied to \\backuppath\VHDX-COPIES

    .INPUTS
    No inputs can be piped into "New-VMSnapshot.ps1"

    .OUTPUTS
    No output is created by New-VMSnapshot.ps1

    .EXAMPLE
    .\New-VMSnapshot.ps1 -VMName <VM Name>

    .EXAMPLE
    .\New-VMSnapshot.ps1 -VMName <VM Name> -AdditionalNotifyEmail <email address>

    .EXAMPLE
    .\New-VMSnapshot.ps1 -VMName <VM Name> -OfflineVHDCopy

#>

param
(
    [Parameter(Mandatory=$true)][string]$VMName,
    [string]$AdditionalNotifyEmail,
    [string]$OutputFile = "VMCheckpoint-" + $VMName + ".csv",
    [switch]$OfflineVHDCopy
)

function Get-ParentVMHost
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$True)][string]$ComputerName
    )
    try
    {
        $strMachineName = $ComputerName
        $objReg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $strMachineName)
        $objRegKey= $objReg.OpenSubKey("SOFTWARE\\Microsoft\\Virtual Machine\\Guest\\Parameters")
        $objRegKey.GetValue("HostName")
    }
    catch
    {
        Write-Error "Unable to determine VM host"
    }
}

function Get-VMVHDX
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$True)][string]$VMName,
        [Parameter(Mandatory=$True)][string]$ParentVMHost
    )
    try
    {
        Get-VM -ComputerName $ParentVMHost -VMName $VMName | Get-VHD -ComputerName $ParentVMHost | select Path
    }
    catch
    {
        Write-Error "Failed to get VM VHDX path"   
    }
}


$HyperVHost = Get-ParentVMHost -ComputerName $VMName
if ($HyperVHost)
{
    if ($OfflineVHDCopy)
    {

        $UserName = "contoso\usr"        
        $password = ""
        $pass = ConvertTo-SecureString $password -AsPlainText -Force 
        $creds = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName,$pass
        
        #Validate that no existing snapshots exist, shut down VM and copy to VHDX share
        if (-not(Get-VMSnapshot -VMName $VMName -ComputerName $HyperVHost))
        {
            $basepath = "\\backuppath\VHDX-COPIES"
            $vhdxpath = $basepath + "\" + $VMName

            #Create directory on backup path for VM, if it doesn't exist
            if(-not(Test-Path -Path $vhdxpath))
            {
                New-Item -ItemType directory -Path $vhdxpath
            }

            #Stop the VM, before copying vhdx('s) and taking checkpoint
            try
            {
                Stop-VM -VMName $VMName -ComputerName $HyperVHost -Verbose -Force
            }
            catch
            {
                Write-Error "Failed to shut down $VMName"
            }

            $vhdxs = (Get-VM -ComputerName $HyperVHost -VMName $VMName | Select-Object vmid | Get-VHD -ComputerName $HyperVHost)
            
            foreach ($vhdx in $vhdxs)
            {                
                Invoke-Command -ComputerName $HyperVHost -ArgumentList $vhdx.path,$vhdxpath,$creds -ScriptBlock { New-PSDrive -Name "V" -PSProvider "FileSystem" -Root $args[1] -Credential $args[2] ; Copy-Item $args[0] -Destination "V:\" -Verbose }
            }
            
            $result = Checkpoint-VM -ComputerName $HyperVHost -Name $VMName -Passthru
            $result | Export-Csv -Path $OutputFile
            Start-VM -ComputerName $HyperVHost -VMName $VMName -Verbose
            
        }
        else
        {
            Write-Error "There is already a HyperV VM snapshot of $VMName. Remove this snapshot first"
        }
        
    }
    else
    {
        $result = Checkpoint-VM -ComputerName $HyperVHost -Name $VMName -Passthru
        $result | Export-Csv -Path $OutputFile
    }    
}

# Email notification of VM snapshot
if (Test-Path $OutputFile)
{    
    $smtpServer = "mail.contoso.com"
    $msg = new-object Net.Mail.MailMessage
    $smtp = new-object Net.Mail.SmtpClient($smtpServer)
    $file = $outputfile
    $att = new-object Net.Mail.Attachment($file)
    $msg.From = "vmsnapshot@contoso.com" 
    $msg.To.Add("notification@contoso.com")
    if ($AdditionalNotifyEmail)
    {
        $msg.To.Add($AdditionalNotifyEmail)
    }
    $msg.subject = "VM Checkpoint created of $VMName"
    $msg.body = "Attached is a report of a snapshot created for $VMName on host $HyperVHost"
    if ($OfflineVHDCopy)
    {
        $msg.body = "Attached is a report of a snapshot created for $VMName on host $HyperVHost `
        Also, vhdx files were copied to $vhdxpath"
    }
    $msg.Attachments.Add($att)
    $smtp.Send($msg)
    $att.Dispose()
    Remove-Item $OutputFile
}