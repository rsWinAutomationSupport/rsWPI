function Get-TargetResource
{
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$Product,
        [String]$AdditionalArgs,
        [Bool]$ForceReboot
    )
    $webpicmd = "C:\Program Files\Microsoft\Web Platform Installer\WebpiCmd.exe"
    $allInstalled = & $webpicmd /List /ListOption:Installed | ConvertFrom-CSV -Delimiter "`t"
    @{
        Product = if( ($allInstalled -match $Product) ) { "$Product Installed" } else { "$Product Not Installed" }
        AdditionalArgs = $AdditionalArgs
        ForceReboot = $ForceReboot
    } 
}

<#
Function Invoke-Process {
    Param($FileName,$Arguments,$timeout)
    if (!($timeout)) {$timeout = 30}
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = New-Object System.Diagnostics.ProcessStartInfo -Property @{
        FileName = $FileName
	    Arguments = $Arguments
	    CreateNoWindow = $true
	    RedirectStandardError = $true
	    RedirectStandardOutput = $true
	    UseShellExecute = $false
    }
    $proc.Start() | Out-Null
    if (!($proc.WaitForExit($timeout*1000))) {$proc.kill()}
    $stderr = $proc.StandardError.ReadToEnd()
    $stdout = $proc.StandardOutput.ReadToEnd()
    $proc.close()
    $proc = $null
    $result = @()
    $result += New-Object psObject -Property @{
        'stdOut'=$stdout
        'stdErr'=$stderr
    } 
    return $result
}
#>

function Set-TargetResource
{
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$Product,
        [String]$AdditionalArgs,
        [Bool]$ForceReboot
    )
    if ( -not (Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{4D84C195-86F0-4B34-8FDE-4A17EB41306A}") )
    {
        try
        {
            if ( -not (Test-Path "C:\rs-pkgs\webpi.msi") )
            {
                Write-Verbose "Downloading WPI.msi"
                Invoke-WebRequest 'http://download.microsoft.com/download/C/F/F/CFF3A0B8-99D4-41A2-AE1A-496C08BEB904/WebPlatformInstaller_amd64_en-US.msi' -OutFile "C:\rs-pkgs\webpi.msi"
            }
        }
        catch [Exception]
        {
            Write-Debug $_.Exception.Message
            return
        }
        Write-Verbose "Installing WPI"
        $process = Start-Process msiexec -ArgumentList "/i C:\rs-pkgs\webpi.msi /qn"  -wait -NoNewWindow -PassThru
        if ( $process.ExitCode -ne 0 ) { Write-Debug "Error Installing WebPI" }
        else { Write-Verbose "Web Platform Installer Completed Successfully"}
    }

    $wpicmd = 'C:\Program Files\Microsoft\Web Platform Installer\WebpiCmd.exe'
    $PMCheck = New-Object Microsoft.Web.PlatformInstaller.ProductManager
    $PMCheck.load()
    $check = $PMCheck.Products | ? {$_.Productid -eq "$Product" -and $_.IsInstalled($true) -eq $true}
        
    if($ForceReboot){$AdditionalArgs += " /ForceReboot"}
    Set-ItemProperty -Path "Registry::HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "Local AppData" -Value "C:\Windows\Temp"
    While ($check.count -lt 1)
    {
        try
        {
            Write-Verbose "Installing $Product"
            $process = & $wpicmd /INSTALL /Products:$Product /AcceptEula $AdditionalArgs
            if($process -match "Install of Products: SUCCESS")
            {
                $check = $PMCheck.Products | ? {$_.Productid -eq "$Product" -and $_.IsInstalled($true) -eq $true}
            }
        }
        catch [Exception]
        {
            Write-Debug $_.Exception.Message
        }
    }
    Set-ItemProperty -Path "Registry::HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "Local AppData" -Value "%USERPROFILE%\AppData\Local"
}

function Test-TargetResource
{
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$Product,
        [String]$AdditionalArgs,
        [Bool]$ForceReboot
    )
    
    if ( -not (Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{4D84C195-86F0-4B34-8FDE-4A17EB41306A}") )
    {
        Write-Verbose "Need to Install Web Platform Installer"
        return $false
    }
    else
    {
        Write-Verbose "Pulling Product installation status."
        $PMCheck = New-Object Microsoft.Web.PlatformInstaller.ProductManager
        $PMCheck.load()
        $check = $PMCheck.Products | ? {$_.Productid -eq "$Product" -and $_.IsInstalled($true) -eq $true}
    
        if($check -lt 1)
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