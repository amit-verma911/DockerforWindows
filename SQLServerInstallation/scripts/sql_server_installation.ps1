<#
.SYNOPSIS

.DESCRIPTION
    This script creates the required folder structure for SQL Server DB Engine
    and installs SQL 2017 using the ITSOE standards

.EXAMPLE

.NOTES
    AUTHOR: Mark Rolstone, Maersk
    LASTEDIT: 6 June 2018

.CHANGE LOG

#>

###########################################################################
# Hard Coded Parameters
###########################################################################
Set-StrictMode -Version 2.0
$SQLCOLLATION ="SQL_Latin1_General_CP1_CI_AS"  #Only change if a specific Collation is required
#$registryPath = "HKEY_LOCAL_MACHINE\SYSTEM\Software\Microsoft"
$registryPath = "HKLM:\SYSTEM\Software\Microsoft"
#$StorageSize = (Get-ItemProperty -Path $registryPath).SQLStorageSize
$bkpsharename = "Backup"
$bkpsharepath = "P:\Backup"
$bkpsharedescription = "Backup Share"
$installfolder = "${env:SystemDrive}\ITSOE\Build\ConfigurationFile_2019"
#$installfolder = "${env:SystemDrive}\Users\bigboss\SQL2019\ConfigurationFile_2019.ini
$DateTime = (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss")
$Global:logfile = "${env:SystemDrive}\ITSOE\Logs\$($DateTime)_SQL_Engine.log"

###########################################################################
# Set Functions
###########################################################################
function Write-Log {              
         Param(    
         [ValidateSet("INFO","WARN","ERROR","FATAL","DEBUG")]
         [String]
         $Level = "INFO",

         [Parameter(Mandatory=$true)]
         [string]
         $Message,
   
         [string]
         $LogFile,
         
         [Parameter(Mandatory=$false)]
         [string]
         $Color = "Green"
         )    
    $DateTime = (Get-Date).ToString("[dd-MM-yyyy HH:mm:ss]")    
    $Log = "$DateTime $Level $Message"
    $LogFolder = Split-Path -Path "$LogFile" -Parent
               
    if (!(Test-Path ($LogFolder))) {            
       New-Item "$LogFolder" -type directory                
    }
     
    If($logfile) {
        Add-Content $LogFile -Value $Log
        Write-Host $Log -ForegroundColor $Color
    }
    Else {
        Write-Output $Line
    }

}

function Get-CurrentFunction {
    return (Get-Variable MyInvocation -Scope 1).Value.MyCommand.Name;
}

function Get-CurrentLineNumber {
    return $MyInvocation.ScriptLineNumber
}

$global:GroupManagedServiceAccount = "example\gMSA-sqladmin$"

Function Input-TextBox{
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Group Managed Service Account'
    $form.Size = New-Object System.Drawing.Size(300,220)
    $form.StartPosition = 'CenterScreen'
    $form.ControlBox =$false

    $OKButton = New-Object System.Windows.Forms.Button
    $OKButton.Location = New-Object System.Drawing.Point(185,140)
    $OKButton.Size = New-Object System.Drawing.Size(75,23)
    $OKButton.Text = 'OK'
    $OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $OKButton
    $form.Controls.Add($OKButton)

    $CancelButton = New-Object System.Windows.Forms.Button
    $CancelButton.Location = New-Object System.Drawing.Point(20,140)
    $CancelButton.Size = New-Object System.Drawing.Size(75,23)
    $CancelButton.Text = 'Cancel'
    $CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $CancelButton
    $form.Controls.Add($CancelButton)

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(20,20)
    $label.Size = New-Object System.Drawing.Size(280,80)
    $label.Text = 'Enter Group Managed Service Account:' + "`n `n" + 'Example example\gMSA-SQLDB0001$'
    $form.Controls.Add($label)

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Point(20,100)
    $textBox.Size = New-Object System.Drawing.Size(240,20)
    $form.Controls.Add($textBox)

    $form.Topmost = $true
    $form.Add_Shown({$form.Activate()})

    $form.Add_Shown({$textBox.Select()})
    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK)
    {
	#$textBox.Text = "example\gMSA-sqladmin$"
        #$global:GroupManagedServiceAccount = $textBox.Text
        #$global:GroupManagedServiceAccount = "example\gMSA-sqladmin$"
    }

    if ($result -eq [system.Windows.Forms.DialogResult]::Cancel)
    {
            Write-Log -Level FATAL -Message "[$(Get-CurrentFunction)] -- [Script Cancelled by User]" -LogFile $Global:LogFile -Color Red        
            exit
    }
}

function Set-Folder(){
         param([string] $Folder        
         )
         Write-Log -Level INFO -Message "** [START] -- [$(Get-CurrentFunction)] -- **" -LogFile $Global:LogFile -Color Magenta
         try
            {
                if (!(Test-Path -PathType Container $Folder))
                {
                    #if (New-Item -ItemType "Directory" -Path $Folder -Force)
                    {
                        Write-Log -Level INFO -Message "** [$(Get-CurrentFunction)] -- Created: $($Folder)" -LogFile $Global:LogFile
                    }
                }
                else {Write-Log -Level INFO -Message "** [$(Get-CurrentFunction)] -- Exists: $($Folder)" -LogFile $Global:LogFile}
            }
        catch
            {
                Write-Log -Level ERROR -Message "** [$(Get-CurrentFunction)] -- [LINE:$($_.InvocationInfo.ScriptLineNumber)] --> $($_.Exception.Message)" -LogFile $Global:LogFile -Color Red
                Write-Log -Level FATAL -Message "** [$(Get-CurrentFunction)] -- [Script Cancelled] **" -LogFile $Global:LogFile -Color Red
                Exit 1    
            }
        Write-Log -Level INFO -Message "** [END] -- [$(Get-CurrentFunction)] -- **" -LogFile $Global:LogFile -Color Magenta
}

Function Install-SQLEngine{
        #Mount Disk Image
        try
            {
                $iso = Get-ChildItem  c:/sqlbinaries/ *.iso -Recurse  
                 
   
            }
        catch
            {
                Write-Log -Level ERROR -Message "** [$(Get-CurrentFunction)] -- SQL Server ISO not found -- **" -LogFile $Global:LogFile -Color Red
                Write-Log -Level FATAL -Message "** [$(Get-CurrentFunction)] -- [Script Cancelled] -- **" -LogFile $Global:LogFile -Color Red
                exit 1
            }

        $isoDrive = Mount-DiskImage -ImagePath $iso.fullname -PassThru
        Write-Log -Level INFO -Message "** [$(Get-CurrentFunction)] -- $iso.fullname mounted  -- **" -LogFile $Global:LogFile

        #Create Run String
        $driveLetter = ($isoDrive | Get-Volume).DriveLetter
        $RunInstall = $driveLetter + ":\Setup.exe"

        #Install SQL Engine Server
        Write-Log -Level INFO -Message "** [$(Get-CurrentFunction)] -- Installing SQL Server Engine Service  -- **" -LogFile $Global:LogFile -Color Magenta
        try
            {
                Start-Process -FilePath $RunInstall  -ArgumentList "/Q /SQLSVCACCOUNT=`"$GroupManagedServiceAccount`" /AGTSVCACCOUNT=`"$GroupManagedServiceAccount`" /ISSVCACCOUNT=`"$GroupManagedServiceAccount`" /SQLTELSVCACCT=`"$GroupManagedServiceAccount`" /ISTELSVCACCT=`"$GroupManagedServiceAccount`" /ConfigurationFile=C:\ITSOE\Build\ConfigurationFile_2019.ini" -Wait
                Write-Log -Level INFO -Message "** [$(Get-CurrentFunction)] -- SQL Server Engine Service Installed -- **" -LogFile $Global:LogFile
            }
        catch
            {
                Write-Log -Level ERROR -Message "** [$(Get-CurrentFunction)] -- Failed to Install SQL Server Engine Service -- **" -LogFile $Global:LogFile -Color Red
                Write-Log -Level FATAL -Message "** [$(Get-CurrentFunction)] -- [Script Cancelled] -- **" -LogFile $Global:LogFile -Color Red
                Dismount-DiskImage -ImagePath $iso.fullname
                Write-Log -Level INFO -Message "** [$(Get-CurrentFunction)] -- $iso.fullname dismounted  -- **" -LogFile $Global:LogFile
                exit 1
            }

        #Dismount SQL Image
        #Dismount-DiskImage -ImagePath $iso.fullname
        Write-Log -Level INFO -Message "** [$(Get-CurrentFunction)] -- $iso.fullname dismounted  -- **" -LogFile $Global:LogFile
    }

Function Add-FirewallRule{
        Param(
        [Parameter(Mandatory=$true)]  
        [String]
        $DisplayName,

        [ValidateSet("True","False")]  
        [String]
        $Enabled ="True",

        [ValidateSet("Allow","Block")]  
        [String]
        $Action = "Allow",

        [ValidateSet("Inbound","Outbound")]  
        [String]
        $Direction = "Inbound",

        [Parameter(Mandatory=$true)]
        [ValidateSet("TCP","UDP")]    
        [String]
        $Protocol,

        [Parameter(Mandatory=$true)]        
        [String]
        $LocalPort,

        [ValidateSet("Any","Domain","Private","Public","NotApplicable")]    
        [String]
        $Profile = "Any"

        )

$err=@()
$Rule = (Get-NetFirewallRule -DisplayName $DisplayName -ErrorAction SilentlyContinue -ErrorVariable err)
if (!$err -eq "")
    {
        $NewRule = (New-NetFirewallRule -DisplayName $DisplayName -Enabled $Enabled -Profile $Profile -Action $Action -Direction $Direction -Protocol $Protocol -LocalPort $LocalPort)
        $NewRulestr = $NewRule|Out-String
        Write-Log -Level INFO -Message "** [$(Get-CurrentFunction)] -- Firewall Rule Created  -- ** $NewRulestr" -LogFile $Global:LogFile
    }
    Else
    {
        $Rulestr = $Rule|Out-String
        Write-Log -Level INFO -Message "** [SKIP] -- Firewall Rule $DisplayName Already Present  -- ** $Rulestr" -LogFile $Global:LogFile -Color Cyan
    }
}

Function Invoke-SQLPost {
        Param(
        [Parameter(Mandatory=$true)]  
        [String]
        $SQLCmd        
        )

$err=@()
$PostCMD = (Invoke-Sqlcmd -InputFile "$installfolder\$SQLCmd" -DisableVariables -querytimeout 0 -ErrorAction SilentlyContinue -ErrorVariable err)
if (!$err -eq "")
    {
        Write-Log -Level WARN -Message "** [$(Get-CurrentFunction)] -- Post Config Command $SQLCmd Failed to Execute -- **" -LogFile $Global:LogFile -Color Yellow
        $Global:bWarning = $True
    }
    Else
    {
        Write-Log -Level INFO -Message "** [$(Get-CurrentFunction)] -- Post Config Command $SQLCmd Excuted Successfully -- **" -LogFile $Global:LogFile
    }
}

function Validate-Gmsa{
    [boolean] $Global:GMSARetry = $False
    [boolean] $Global:GMSAValid = $False
    Write-Log -Level INFO -Message "** [Start] -- [$(Get-CurrentFunction)] -- **" -LogFile $Global:LogFile -Color Magenta

    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null

    Input-TextBox

    if (!($Global:GroupManagedServiceAccount.Length) -or ($Global:GroupManagedServiceAccount -eq ""))
    {
        $MsgResult = [System.Windows.Forms.MessageBox]::Show('Group Managed Service Account is Null','Script Failed','RetryCancel','Error')
        Write-Log -Level ERROR -Message "** [$(Get-CurrentFunction)] -- [Group Managed Service Account is Null]" -LogFile $Global:LogFile -Color Red
        If($MsgResult -eq "Retry")
        {          
            Write-Log -Level INFO -Message "** [$(Get-CurrentFunction)] -- [Retry Group Managed Service Account Validation]" -LogFile $Global:LogFile
            $Global:GmsaRetry = $true
            Return
        }
        Elseif($MsgResult -eq "Cancel")
        {
            Write-Log -Level FATAL -Message "** [$(Get-CurrentFunction)] -- [Script Cancelled]" -LogFile $Global:LogFile -Color Red        
            $Global:GMSAValid -eq $false            
            Return
        }
    }

    if (!$Global:GroupManagedServiceAccount.StartsWith("example\gMSA-","CurrentCultureIgnoreCase"))
    {
        [String[]]$Msg = @()
        $Msg += "The example Domain must be specified"
        $Msg += 'For example: example\gMSA-SQLASnnnn$'
        [String]$MsgTxt = ''
        $Msg | ForEach-Object { $MsgTxt += $_ + "`n" }
        $MsgResult = [System.Windows.Forms.MessageBox]::Show($Msg,'Script Failed','RetryCancel','Error')
        Write-Log -Level ERROR -Message "[$(Get-CurrentFunction)] -- [Group Managed Service Account format incorrect - Domain not set]" -LogFile $Global:LogFile -Color Red
        If($MsgResult -eq "Retry")
        {          
            Write-Log -Level INFO -Message "** [$(Get-CurrentFunction)] -- [Retry Group Managed Service Account Validation]" -LogFile $Global:LogFile
            $Global:GmsaRetry = $true
            Return
        }
        Elseif($MsgResult -eq "Cancel")
        {
            Write-Log -Level FATAL -Message "** [$(Get-CurrentFunction)] -- [Script Cancelled]" -LogFile $Global:LogFile -Color Red        
            $Global:GMSAValid -eq $false            
            Return
        }
    }

    if (!$Global:GroupManagedServiceAccount.EndsWith("$"))
    {
        [String[]]$Msg = @()
        $Msg += "$ must be at end of the gMSA account"
        $Msg += 'For example: example\gMSA-SQLASnnnn$'
        [String]$MsgTxt = ''
        $Msg | ForEach-Object { $MsgTxt += $_ + "`n" }
        $MsgResult = [System.Windows.Forms.MessageBox]::Show($Msg,'Script Failed','RetryCancel','Error')
        Write-Log -Level ERROR -Message "** [$(Get-CurrentFunction)] -- [Group Managed Service Account format incorrect - not ending with $]" -LogFile $Global:LogFile -Color Red
        If($MsgResult -eq "Retry")
        {          
            Write-Log -Level INFO -Message "** [$(Get-CurrentFunction)] -- [Retry Group Managed Service Account Validation]" -LogFile $Global:LogFile
            $Global:GmsaRetry = $true
            Return
        }
        Elseif($MsgResult -eq "Cancel")
        {
            Write-Log -Level FATAL -Message "** [$(Get-CurrentFunction)] -- [Script Cancelled]" -LogFile $Global:LogFile -Color Red        
            $Global:GMSAValid -eq $false            
            Return
        }
    }

    ##Check gMSA is installed on Server
    $err=@()
    $GMSATest = $GLobal:GroupManagedServiceAccount.tolower().trimstart("example\")
    $Result = Get-ADServiceAccount $GMSATest -ErrorAction SilentlyContinue -ErrorVariable err
    if (!$err -eq "")
    {
        $MsgResult = [System.Windows.Forms.MessageBox]::Show("$Global:GroupManagedServiceAccount does not exist in Active Directory",'Script Failed','RetryCancel','Error')
        Write-Log -Level ERROR -Message "** [$(Get-CurrentFunction)] -- [$Global:GroupManagedServiceAccount does not exist in Active Directory]" -LogFile $Global:LogFile -Color Red
        If($MsgResult -eq "Retry")
        {          
            Write-Log -Level INFO -Message "** [$(Get-CurrentFunction)] -- [Retry Group Managed Service Account Validation]" -LogFile $Global:LogFile
            $Global:GmsaRetry = $true
            Return
        }
        Elseif($MsgResult -eq "Cancel")
        {
            Write-Log -Level FATAL -Message "** [$(Get-CurrentFunction)] -- [Script Cancelled]" -LogFile $Global:LogFile -Color Red        
            $Global:GMSAValid -eq $false            
            Return
        }
    }

    $GMSAInstalled = Test-ADServiceAccount $GMSATest
    Add-Type -AssemblyName System.Windows.Forms
    if ($GMSAInstalled -eq $false )
    {
        [String[]]$Msg = @()
        $Msg += "The gMSA $Global:GroupManagedServiceAccount is not installed on this server"
        $Msg += 'Check you have the correct gMSA account and that'
        $Msg += 'the computer account has been added to the gMSA Group in Active Directory'
        [String]$MsgTxt = ''
        $Msg | ForEach-Object { $MsgTxt += $_ + "`n" }    
        [System.Windows.Forms.MessageBox]::Show($MsgTxt,'Script Failed','OK','Error')
        Write-Log -Level ERROR -Message "** [$(Get-CurrentFunction)] -- [$Global:GroupManagedServiceAccount not installed on server]" -LogFile $Global:LogFile -Color Red
        Write-Log -Level FATAL -Message "** [$(Get-CurrentFunction)] -- [Script Cancelled]" -LogFile $Global:LogFile -Color Red        
            $Global:GMSAValid -eq $false            
            Return
    }
    $Global:GMSAValid = $true
    Write-Log -Level INFO -Message "** [$(Get-CurrentFunction)] -- gMSA $Global:GroupManagedServiceAccount Validated " -LogFile $Global:LogFile    
    Write-Log -Level INFO -Message "** [END] -- [$(Get-CurrentFunction)] -- **" -LogFile $Global:LogFile -Color Magenta
}

Function Add-Syslogin(){
param(
    [Parameter(Mandatory = $true)][String]$LoginName
)

$SQLSysAdmin = (get-sqllogin -ServerInstance $env:computername)
if($SQLSysAdmin.name -contains $LoginName)
{
Write-Log -Level INFO -Message "** [INFO] -- $LoginName already a member of SysAdmins -- **" -LogFile $Global:LogFile -Color Cyan
}
Else
{
Write-Log -Level INFO -Message "** [START] -- Adding $LoginName Account to SysAdmins -- **" -LogFile $Global:LogFile -Color Magenta
try
{
add-Sqllogin -ServerInstance $env:computername -LoginName $LoginName -LoginType WindowsUser -DefaultDatabase Master -Enable -GrantConnectSql
Write-Log -Level INFO -Message "** [EVENT] -- Added $LoginName Account to SysAdmins -- **" -LogFile $Global:LogFile
}
catch
{
Write-Log -Level INFO -Message "** [EVENT] -- Failed to Add $LoginName Account to SysAdmins -- **" -LogFile $Global:LogFile -Color Yellow
$Global:bWarning -eq $True
}    
Write-Log -Level INFO -Message "** [STOP] -- Adding $LoginName Account to SysAdmins -- **" -LogFile $Global:LogFile -Color Magenta
}
}

Function Set-SQLStartupParam{
param(
    [Parameter(Mandatory = $true)][String]$StartupParameters
)
Write-Log -Level INFO -Message "** [START] -- [$(Get-CurrentFunction)] --  **" -LogFile $Global:LogFile -Color Magenta

# get all the instances on a server
$property = Get-ItemProperty "HKEY_LOCAL_MACHINE\SYSTEM\Software\Microsoft\Microsoft SQL Server\Instance Names\SQL"

$instancesObject = $property.psobject.properties | ?{$_.Value -like 'MSSQL*'}
$instances = $instancesObject.Value

#get all the parameters you input
$parameters = $StartupParameters.split(",")

#add all the startup parameters
if($instances)
    {
        foreach($instance in $instances)
        {
            $ins = $instance.split('.')[1]
            if($ins -eq "MSSQLSERVER")
                {
                    $instanceName = $env:COMPUTERNAME
                }
            else
                {
                    $instanceName = $env:COMPUTERNAME + "\" + $ins
                }
            $regKey = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instance\MSSQLServer\Parameters"
            $property = Get-ItemProperty $regKey
            #$property
            $paramObjects = $property.psobject.properties | ?{$_.Name -like 'SQLArg*'}
            $count = $paramObjects.count
            foreach($parameter in $parameters)
                {
                    if($parameter -notin $paramObjects.value)
                        {                
                            Write-Log -Level INFO -Message "** [$(Get-CurrentFunction)] -- Adding startup parameter: $parameter for $instanceName -- **" -LogFile $Global:LogFile
                            $newRegProp = "SQLArg"+$count
                            Set-ItemProperty -Path $regKey -Name $newRegProp -Value $parameter
                            $count = $count + 1
                        }
                }
        }
    }
Write-Log -Level INFO -Message "** [$(Get-CurrentFunction)] -- All startup parameters added for $instanceName -- **" -LogFile $Global:LogFile
Write-Log -Level INFO -Message "** [STOP] -- [$(Get-CurrentFunction)] --  **" -LogFile $Global:LogFile -Color Magenta
}

Function Write-Complete {
if ($bWarning -eq $False)
    {
        Write-Log -Level INFO -Message "** [COMPLETE] -- Install SQL Server Engine Service  -- **" -LogFile $Global:LogFile
        if($bReboot -eq $true)
            {
                Write-Log -Level INFO -Message "** [EVENT] -- Restarting Computer  -- **" -LogFile $Global:LogFile
                Start-Sleep -s 60
                Restart-Computer
            }
    }
Else
    {
        Write-Log -Level WARN -Message "** [COMPLETE] -- Install SQL Server Engine Service completed with Warnings  -- **" -LogFile $Global:LogFile -Color Yellow
        Write-Log -Level WARN -Message "** [WARNING] -- Review the log file $Global:LogFile  -- **" -LogFile $Global:LogFile -Color Yellow
        Write-Log -Level WARN -Message "** [WARNING] -- Restart Computer Once Installation Issues have been Addressed -- **" -LogFile $Global:LogFile -Color Yellow
    }
}

###########################################################################
# Start Script
###########################################################################
[boolean] $Global:bWarning = $False
[boolean] $Global:bReboot = $False
Write-Log -Level INFO -Message "** [START] -- SQL Engine Installation Script -- **" -LogFile $Global:LogFile -Color Magenta
$IsInstalled = (get-service | where {$_.Name -eq "MSSQLServer"})
If(!$IsInstalled -eq "")
    {
        Write-Log -Level INFO -Message "** [SKIP] -- SQL Server Engine Already Installed -- **" -LogFile $Global:LogFile -Color Cyan
        $GroupManagedServiceAccount = (Get-ItemProperty -Path $registryPath).SQLgMSA
             #$GroupManagedServiceAccount = "example\gMSA-sqladmin$"
    }
Else
    {
        #Validate-Gmsa | Out-Null

        #If($Global:GmsaRetry -eq $true)
            #{
             #   Validate-Gmsa | Out-Null
           # }

#        if($Global:GMSAValid -eq $false)
 #           {
  #              Exit
		#Write-Log -Level INFO -Message "**  [ACTION] -- GroupManagedServiceAccount  hardcodded written to Registry -- **"
            #}

      #New-ItemProperty -Path HKLM:\SYSTEM\Software\Microsoft -Name SQLgMSA -Value example\gMSA-sqladmin$ -PropertyType String -Force | Out-Null
      New-ItemProperty -Path $registryPath -Name SQLgMSA -Value $Global:GroupManagedServiceAccount -PropertyType String -Force | Out-Null
      Write-Log -Level INFO -Message "**  [ACTION] -- gMSA $Global:GroupManagedServiceAccount written to Registry -- **" -LogFile $Global:LogFile

        #Create folders
        Write-Log -Level INFO -Message "** [START] -- Creating Folder Structure -- **" -LogFile $Global:LogFile -Color Magenta
        Set-Folder "C:\MSSQL\" |Out-Null
        Set-Folder "F:\DATA\" |Out-Null
        Set-Folder "H:\LOG\" |Out-Null
        Set-Folder "I:\BACKUP\" |Out-Null
        Set-Folder "C:\DATA\" |Out-Null
        Set-Folder "I:\TempData" |Out-Null
        Set-Folder "I:\TempLog" |Out-Null
        #if($StorageSize -eq "xlarge")
            #{
                #Set-Folder "C:\DATA\" |Out-Null
                #Set-Folder "C:\DATA\" |Out-Null
                #Set-Folder "C:\DATA\" |Out-Null
                #Set-Folder "C:\BACKUP\" |Out-Null
            #}
        Write-Log -Level INFO -Message "** [STOP] -- Creating Folder Structure -- **" -LogFile $Global:LogFile -Color Magenta

        ###########################################################################
        # Install SQL
        ###########################################################################
        Write-Log -Level INFO -Message "** [START] -- Install-SQLEngine -- **" -LogFile $Global:LogFile -Color Magenta
        Install-SQLEngine
        $Global:bReboot = $True
        Write-Log -Level INFO -Message "** [STOP] -- Install-SQLEngine -- **" -LogFile $Global:LogFile -Color Magenta
    }
