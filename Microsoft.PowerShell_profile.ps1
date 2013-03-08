#
# Ryan Mechelke's PowerShell Profile
#

Write-Host `nPowerShell Profile loading... -foregroundcolor yellow

# VARIABLES {{{

Write-Host Defining custom variables... -foregroundcolor yellow

$psdrives = "$home/psdrives"
$scripts = "$home/scripts/psh"

# END VARIABLES }}}

# FUNCTIONS {{{

Write-Host Defining custom functions... -foregroundcolor yellow

#### Functions Used to Load VS Command Prompt #####
function Get-Batchfile ($file) {
    $cmd = "`"$file`" & set"
    cmd /c $cmd | Foreach-Object {
        $p, $v = $_.split('=')
        Set-Item -path env:$p -value $v
    }
}
function Set-VsVars32($vsYear)
{
   switch ($vsYear)
   {
        2008 {$vstools = $env:VS90COMNTOOLS}
        2010 {$vstools = $env:VS100COMNTOOLS }
   }

   $batchFile = [System.IO.Path]::Combine($vstools, "vsvars32.bat") 
   
   Get-Batchfile -file $batchFile
   
   Write-Host -ForegroundColor 'Yellow' "VsVars has been loaded from: $batchFile"
}

# function to make adding FS drives easy
function New-Drive ($name, $loc) {
    Write-Host "`t$name -`> $loc" -foregroundcolor yellow
    try {
        New-PSDrive -name $name -psprovider FileSystem -root $loc -scope Global -erroraction Stop | Out-Null
    } catch {
        if ($error[0].FullyQualifiedErrorId -eq "DriveAlreadyExists,Microsoft.PowerShell.Commands.NewPSDriveCommand") {
            # do nothing
        } else {
            throw $error[0].Exception
        }
    }
}

function Load-PSDrives () {
    if ( [io.File]::Exists($psdrives) ) {
        Write-Host Parsing from psdrives config -foregroundcolor yellow
        Get-Content $psdrives | % {
            $split = $_.split(" ")
            $drive = $split[0]
            $path = $split[1]
            New-Drive $drive $path
        }
    }
}

# add new drives to psdrives files
function Add-Drive ($name, $loc) {
    echo "$name $loc" | Out-File -encoding ASCII -append $psdrives
    New-Drive $name $loc
}

function Remove-Drive ($name) {
    Write-Host "Removing drive $name" -foregroundcolor yellow

    try {
        Select-String -NotMatch "^$name" $psdrives | % { $_.line } | Out-File -encoding ASCII "$psdrives.new"
        Remove-Item $psdrives
        Rename-Item "$psdrives.new" $psdrives
        Remove-PSDrive $name -erroraction Stop | Out-Null
    } catch {
        if ($error[0].FullyQualifiedErrorId -eq "DriveNotFound,Microsoft.Powershell.COmmands.RemovePSDriveCommand") {
            Write-Host "No such drive: $name" -foregroundcolor red
        } else {
            throw $error[0].Exception
        }
    }
}

function Remap-Drive ($name, $loc) {
    Write-Host "Remapping drive $name" -foregroundcolor yellow
    Remove-Drive $name
    Add-Drive $name $loc
}

# calculate md5 of files
function Get-MD5 ([string]$path, [switch]$recurse, [string]$basePath=$null) {
    $md5 = [Security.Cryptography.MD5]::Create()
    $fs = $null;
    $path = Convert-Path $path

    if ($basePath -eq "") {
        Write-Host
        if ([io.Directory]::Exists($path)) {
            $basePath = $path
        } else {
            $basePath = [io.Path]::GetDirectoryName($path)
        }

        if (!$basePath.EndsWith([io.Path]::DirectorySeparatorChar)) {
            $basePath += [io.Path]::DirectorySeparatorChar
        }
    }

    if ([io.File]::Exists($path)) {
        try {
            $fs = [io.File]::Open($path, [io.FileMode]::Open, [io.FileAccess]::Read, [io.FileShare]::Read)
            if ($fs) {
                $hash = $md5.ComputeHash($fs)
                $fs.Close()

                $hash | % {
                    Write-Host -nonewline $_.ToString("X2")
                }
            }
        } catch {
            Write-Host "Error reading file              " -nonewline -foregroundcolor red
        }

        Write-Host " $($path.Replace($basePath, `"`"))"

    } elseif ([io.Directory]::Exists($path)) {
        [io.Directory]::GetFileSystemEntries($path) | % {
            if ([io.Directory]::Exists($_)) {
                if ($recurse) {
                    Get-MD5 $_ -recurse -basePath $basePath
                }
            } else {
                Get-MD5 $_ -basePath $basePath
            }
        }
    }
}

# load a script and catch errors
function Load-Script($path) {
    $name = [io.Path]::GetFileName($path) 
    try {
        . $path
        Write-Host "`t$name" -foregroundcolor yellow
    } catch {
        Write-Host "`t$name" -foregroundcolor red
    }
}
# END FUNCTIONS }}}

# DRIVES {{{

Write-Host Creating custom drives... -foregroundcolor yellow

Load-PSDrives


# New-Drive sofodev c:\code\sofodev
# New-Drive priv \\bling\users\ryanm\private
# New-Drive pub \\bling\users\ryanm\public

# END DRIVES }}}

# SETTINGS {{{

Write-Host Applying custom settings... -foregroundcolor yellow

Set-VsVars32 2010
#  END SETTINGS }}}

# SCRIPTS {{{
Write-Host Loading scripts... -foregroundcolor yellow
ls $scripts | % {
    if ([io.Path]::GetExtension($_) -eq ".ps1") {
        Load-Script $_.VersionInfo.FileName
    }
}
# END SCRIPTS }}}

Write-Host Done!`n -foregroundcolor yellow

# vim: fdm=marker
