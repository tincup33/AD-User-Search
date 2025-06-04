Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass -Force
$ErrorActionPreference = "SilentlyContinue"
Import-Module ActiveDirectory
cls

# Timestamp conversion
function Convert-LastLogon {
    param([long]$timestamp)
    if ($timestamp -ne 0) {
        return [DateTime]::FromFileTime($timestamp)
    } else {
        return "User has never logged in"
    }
}

function Get-CNName {
    param([string]$distinguishedName)
    if ($distinguishedName -match '^CN=([^,]+)') {
        return $matches[1]
    }
    return $distinguishedName
}

# User properties and group ownership/membership info
function Show-UserDetails {
    param ($user)

    $lastlogon = Convert-LastLogon -timestamp $user.LastLogon

    Write-Host "`nUser Information" -ForegroundColor Cyan
    Write-Host "----------------`n"

    [PSCustomObject]@{
        'Username' = $user.SamAccountName
        'Full Name' = $user.DisplayName
        'Email' = $user.EmailAddress
        'Title' = $user.Title
        'Department' = $user.Department
        'Department Number' = ($user.DepartmentNumber -join ', ')
		'Location' = $user.Office
        'Active' = $user.Enabled
        'Locked' = $user.LockedOut
        'Last Logon' = $lastlogon
        'Account Created' = $user.Created
        'Password Last Changed' = $user.PasswordLastSet
    } | Format-List

    # Group Ownership
    Write-Host "`nGroup Ownership" -ForegroundColor Cyan
    Write-Host "---------------`n"
    if ($user.managedObjects) {
        $user.managedObjects | ForEach-Object { Get-CNName $_ } | Sort-Object | ForEach-Object {
            Write-Host $_ -ForegroundColor Magenta
        }
    } else {
        Write-Host "None"
    }

    # Group Membership
    Write-Host "`nGroup Membership" -ForegroundColor Cyan
    Write-Host "----------------`n"
    if ($user.MemberOf) {
        $user.MemberOf | ForEach-Object { Get-CNName $_ } | Sort-Object | ForEach-Object {
            Write-Host $_ -ForegroundColor Green
        }
    } else {
        Write-Host "None"
    }
}

# Search for and display user infomation
function Get-UserInfo {
    $inputValue = Read-Host "`nEnter Username or Full Name (partial or full)"
    cls

    try {
        $props = 'SamAccountName','DisplayName','EmailAddress','Title','Department','DepartmentNumber',
                 'Office','Enabled','LockedOut','LastLogon','Created','PasswordLastSet','MemberOf','ManagedObjects'

        $users = @(Get-ADUser -Filter "SamAccountName -like '*$inputValue*' -or DisplayName -like '*$inputValue*'" -Properties $props)

        if ($users.Count -eq 0) {
            Write-Host "User not found." -ForegroundColor Yellow
        }
        elseif ($users.Count -eq 1) {
            Show-UserDetails -user $users[0]
        }
        else {
            Write-Host "`nMultiple users found!`n" -ForegroundColor Cyan

            for ($i = 0; $i -lt $users.Count; $i++) {
                $user = $users[$i]
                Write-Host "$($i + 1). $($user.DisplayName) [$($user.SamAccountName)]"
            }

            do {
                $selection = Read-Host "`nEnter the number of the user to view details (or press Enter to cancel)"
                if ($selection -eq "") {
                    Write-Host "`nCancelled selection." -ForegroundColor Yellow
                    return
                }
            } while (-not ($selection -as [int]) -or [int]$selection -lt 1 -or [int]$selection -gt $users.Count)

            $user = $users[[int]$selection - 1]
            Show-UserDetails -user $user
        }

    } catch {
        Write-Host "An error occurred: $_`n" -ForegroundColor Red
    }
}

# User info command
Get-UserInfo

# Ask user if they want to search for another user
do {
    do {
        $searchAgain = Read-Host "`nWould you like to search again? (Y/N)"
        if ($searchAgain -notmatch '^[YyNn]$') {
            Write-Host "Please enter Y or N." -ForegroundColor Yellow
        }
    } while ($searchAgain -notmatch '^[YyNn]$')

    if ($searchAgain -match '^[Yy]$') {
        Get-UserInfo
    }
} while ($searchAgain -match '^[Yy]$')

cls