### CONFIG

param (
    [parameter(mandatory)][string]$path,
    [switch]$whatif
)

if (!(Test-Path -LiteralPath $path)) {
    Write-Output "Source not available."
    Exit
}

$folders = @()
$filesToMove = @()
$filesToDelete = @()

$folders += Get-ChildItem -LiteralPath $path -Directory -Recurse
$filesToMove += $folders | ForEach-Object {Get-ChildItem -LiteralPath $_.FullName | Where-Object { ! $_.PSIsContainer }}

foreach ($file in $filesToMove)
{
    $destination = Join-Path $path $file.Name

    # Check if file already exists
    $num=1
    while ((Test-Path -LiteralPath $destination) -and (Test-Path -LiteralPath $file.FullName)) {
        # Compare the files if they are the same
        if ((Get-FileHash $destination).Hash -eq (Get-FileHash $file.FullName).Hash) {
            $filesToDelete += $file
            break
        } else {
            # If they are not the same add a suffix to it
            $destination = Join-Path $path ($file.BaseName + "_$num" + $file.Extension)
            $num+=1
        }
    }

    if (Test-Path -LiteralPath $file.FullName) {
        if ($whatif -eq $true) {
            $movedFile = Move-Item -LiteralPath $file.FullName -Destination $destination -passThru -whatif
        } else {
            $movedFile = Move-Item -LiteralPath $file.FullName -Destination $destination -passThru
        }
    }
    Write-Output $movedFile
}

foreach ($file in $filesToDelete)
{
    if (Test-Path -LiteralPath $file.FullName) {
        if ($whatif -eq $true) {
            $deletedFile = Remove-Item -LiteralPath $file.FullName -Force -WhatIf
        } else {
            $deletedFile = Remove-Item -LiteralPath $file.FullName -Force
        }
    }
    Write-Output $deletedFile
}

# Delete all empty folders
$foldersToDelete = @()

foreach ($folder in (Get-ChildItem -LiteralPath $path -Recurse `
    | Where-Object { $_.PSIsContainer }))
{
    $foldersToDelete += New-Object PSObject -Property @{
        Object = $folder
        Depth = ($folder.FullName -split "\\").count
    }
}
$foldersToDelete = $foldersToDelete | Sort-Object Depth -Descending

foreach ($folder in $foldersToDelete)
{
    If ($folder.Object.GetFileSystemInfos().count -eq 0)
    { 
        $deletedFolder = Remove-Item -LiteralPath $folder.Object.FullName
    }
    Write-Output $deletedFolder
}