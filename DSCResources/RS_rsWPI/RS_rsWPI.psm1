function Get-TargetResource
{
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$Product,
        [String]$AdditionalArgs,
        [System.Boolean]$ForceReboot
    )
    $webpicmd = "C:\Program Files\Microsoft\Web Platform Installer\WebpiCmd.exe"
    [reflection.assembly]::LoadWithPartialName("Microsoft.Web.PlatformInstaller") | Out-Null
    $PMCheck = New-Object Microsoft.Web.PlatformInstaller.ProductManager
    $PMCheck.load()
    $check = $PMCheck.Products | ? {$_.Productid -eq "$Product" -and $_.IsInstalled($true) -eq $true}
    @{
        Product = if( ($check.count -ge 1) ) { "$Product Installed" } else { "$Product Not Installed" }
        AdditionalArgs = $AdditionalArgs
        ForceReboot = $ForceReboot
    } 
}

function Set-TargetResource
{
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$Product,
        [String]$AdditionalArgs,
        [System.Boolean]$ForceReboot
    )
    if ( -not (Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{4D84C195-86F0-4B34-8FDE-4A17EB41306A}") )
    {
        try
        {
            if ( -not (Test-Path "C:\Windows\Temp\webpi.msi") )
            {
                Write-Verbose "Downloading WPI.msi"
                Invoke-WebRequest 'http://download.microsoft.com/download/C/F/F/CFF3A0B8-99D4-41A2-AE1A-496C08BEB904/WebPlatformInstaller_amd64_en-US.msi' -OutFile "C:\Windows\Temp\webpi.msi"
            }
        }
        catch [Exception]
        {
            Write-Debug $_.Exception.Message
            return
        }
        Write-Verbose "Installing WPI"
        $process = Start-Process msiexec -ArgumentList "/i C:\Windows\Temp\webpi.msi /qn"  -wait -NoNewWindow -PassThru
        if ( $process.ExitCode -ne 0 ) { Write-Debug "Error Installing WebPI" }
        else { Write-Verbose "Web Platform Installer Completed Successfully"}
    }

    $wpicmd = 'C:\Program Files\Microsoft\Web Platform Installer\WebpiCmd.exe'
    [reflection.assembly]::LoadWithPartialName("Microsoft.Web.PlatformInstaller") | Out-Null
    $PMCheck = New-Object Microsoft.Web.PlatformInstaller.ProductManager
    $PMCheck.load()
    $check = $PMCheck.Products | ? {$_.Productid -eq "$Product" -and $_.IsInstalled($true) -eq $true}
    $safety = & $wpicmd /list /ListOption:Installed
        
    if($ForceReboot){$AdditionalArgs += " /ForceReboot"}
    Set-ItemProperty -Path "Registry::HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "Local AppData" -Value "C:\Windows\Temp"
    do {
        Write-Verbose "Installing $Product"
        $process = & $wpicmd /INSTALL /Products:$Product /AcceptEula $AdditionalArgs
        $PMCheck.load()
        $check = $PMCheck.Products | ? {($_.Productid -eq "$Product") -and ($_.IsInstalled($true) -eq $true)}
        $safety = & $wpicmd /list /ListOption:Installed
        if($process -match "Install of Products: SUCCESS")
           {
                Write-Verbose "Installer marked installation Successful"
            }
    }
    While (($check.count -lt 1) -or (!($safety -match $Product)))
    Set-ItemProperty -Path "Registry::HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "Local AppData" -Value "%USERPROFILE%\AppData\Local"
}

function Test-TargetResource
{
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$Product,
        [String]$AdditionalArgs,
        [System.Boolean]$ForceReboot
    )
    
    if ( -not (Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{4D84C195-86F0-4B34-8FDE-4A17EB41306A}") )
    {
        Write-Verbose "Need to Install Web Platform Installer"
        return $false
    }
    else
    {
        Write-Verbose "Pulling Product installation status."
        [reflection.assembly]::LoadWithPartialName("Microsoft.Web.PlatformInstaller") | Out-Null
        $PMCheck = New-Object Microsoft.Web.PlatformInstaller.ProductManager
        $PMCheck.load()
        $check = $PMCheck.Products | ? {$_.Productid -eq "$Product" -and $_.IsInstalled($true) -eq $true}
    
        if($check.count -lt 1)
        {
            Write-Verbose "Need to Install $Product"
            $testresult = $false
        }
        else
        {
            Write-Verbose "$Product is Installed."
            $testresult = $true
        }
        return $testresult
    }
}
Export-ModuleMember -Function *-TargetResource