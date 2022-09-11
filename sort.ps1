### CONFIG

$filter = "Alle"
$filter = Read-Host -Prompt "Welche Kategorie soll sortiert werden? (Bilder, Diverses, Filme, Musik, Programme, Serien, Spiele, Video, Alle)"

$path = "D:\complete\"
$destination = "D:\complete"
$passThru = 1
$whatif = 0

$Logfile = "D:\Logs\$(gc env:computername)_$.log"

$extensionMappings = @{
    ".mp3" = @{ category = "Musik" }
    ".flac" = @{ category = "Musik" }
    ".wav" = @{ category = "Musik" }
    ".jpg" = @{ category = "Bilder"; keepWith = @(".mp3", ".flac", ".exe", ".msi"); keepWithout = 1; }
    ".jpeg" = @{ category = "Bilder"; keepWith = @(".mp3", ".flac", ".exe", ".msi"); keepWithout = 1; }
    ".png" = @{ category = "Bilder"; keepWith = @(".mp3", ".flac", ".exe", ".msi"); keepWithout = 1; }
    ".gif" = @{ category = "Bilder"; keepWith = @(".mp3", ".flac", ".exe", ".msi"); keepWithout = 1; }
    ".mp4" = @{ category = "Video" }
    ".mkv" = @{ category = "Video"; keepWith = @(".nfo"); keepWithout = 1; }
    ".wmv" = @{ category = "Video" }
    ".mov" = @{ category = "Video" }
    ".flv" = @{ category = "Video" }
    ".f4v" = @{ category = "Video" }
    ".mpg" = @{ category = "Video" }
    ".avi" = @{ category = "Video" }
    ".m4v" = @{ category = "Video" }
    ".divx" = @{ category = "Video" }
    ".mpeg" = @{ category = "Video" }
    ".srt" = @{ category = "Video"; keepWith = @(".mkv"); keepWithout = 0; }
    ".nfo" = @{ category = "Video"; keepWith = @(".mkv"); keepWithout = 0; }
    ".pdf" = @{ category = "Diverses" }
}

$extensionMappingsHighPrio = @{
    ".msi" = @{ category = "Programme" }
    ".exe" = @{ category = "Programme" }
    ".zip" = @{ category = "Programme"; keepWith = @(".exe", ".msi"); skipWithout = 1; }
    ".7zip" = @{ category = "Programme"; keepWith = @(".exe", ".msi"); skipWithout = 1; }
    ".rar" = @{ category = "Programme"; keepWith = @(".exe", ".msi"); skipWithout = 1; }
}

$extensionMappingsToDelete = @(".html", ".gif", ".url", ".m3u", ".par2", ".sfv", ".lnk", ".info", ".cue", ".log", ".diz")
$rootFolder = @("Bilder", "Diverses", "Filme", "Musik", "Programme", "Serien", "Spiele", "Video")

### SCRIPT

Function Write-Log {
   Param ([string]$logstring)

   Add-content $Logfile -value $logstring
}

$extensionFilter = @($extensionMappings.Keys |% {"*$_" })
$extensionFilterHighPrio = @($extensionMappingsHighPrio.Keys |% {"*$_" })
$filesToMove = @(Get-ChildItem -Path $path -Recurse -Include $extensionFilter |? { $rootFolder -notcontains (($_ -split "\\")[2]) })
$filesToMoveHighPrio = @(Get-ChildItem -Path $path -Recurse -Include $extensionFilterHighPrio |? { $rootFolder -notcontains (($_ -split "\\")[2]) })
$filesToMove = [array]$filesToMoveHighPrio + [array]$filesToMove

Write-Log "Moved Files:"
foreach ($file in $filesToMove)
{
    # Make sure the right category is used
    if ($extensionMappingsHighPrio[$file.Extension]) 
    {   
        $mapping = $extensionMappingsHighPrio[$file.Extension] } 
    else 
    {
        $mapping = $extensionMappings[$file.Extension]
    }
    $category = $mapping.category

    # Fallback if no category is set, should not be triggered
    if (-not $category) { $category = "Diverses" }
    
    # Keep some files in other categories
    if ($mapping -and $mapping.keepWith) 
    {
        # Look for a sibling in the same folder but different extension
        $sibling = $filesToMove |? { $_.Extension -notmatch $file.Extension} `
            |? { $file.FullName -like (Split-Path $_.FullName -parent)+"*" } `
            |? { $mapping.keepWith -contains $_.Extension } `
            | Select -First 1

        if ($sibling)
        {
            # If we found a sibling, then use its category for this file:
            $siblingCategory = $extensionMappings[$sibling.Extension].category
            $category = if ($siblingCategory) { $siblingCategory } else { $category }
        } elseif ($mapping.keepWithout -eq 0) {
            Remove-Item -LiteralPath $file -Force
            continue
        } elseif ($mapping.skipWithout -eq 1) {
            continue
        }
    }

    # Split video category in movie, series and video
    if ($file.Extension -eq ".mkv" -and $sibling) { $category = "Filme" }
    if ($file.Extension -eq ".nfo" -and $sibling) { $category = "Filme" }
    if ($file.BaseName -match "S\d{2}E\d{2}" -or $file.BaseName -match "One Piece") { $category = "Serien" }

    if (($category -ne $filter) -and ($filter -ne "Alle"))
    {
        continue
    }

    # Default paths
    $destinationSubFolder = $file.Directory.ToString().Replace($path, "")
    $destinationCategoryPath = Join-Path $destination $category

    # Get subfolders
    $fileSubFolder = (($file -split "\\")[2..(($file -split "\\").count -2)])
    $fileSubFolderCount = (($file -split "\\").count -3)

    # Eliminate unnecessary subfolders  
    if ($fileSubFolderCount -gt 0) {
        if ($category -eq "Bilder") {
            # Write-Output "Kategorie Bilder"
            $destinationFile = Join-Path $destinationCategoryPath $file.Name
            if ($fileSubFolder -eq "img" -and $fileSubFolderCount -gt 1 -and $extensionMappings.Keys -contains "."+(($file.BaseName -split "\.")[1]))
            {
                Remove-Item -LiteralPath $file -Force
                continue
            }
            if ($fileSubFolder[0] -eq "Verschiedene Dateien" -and $fileSubFolderCount -gt 1) 
            {
                $destinationFile = Join-Path $destinationCategoryPath $fileSubFolder[1]
                for ($i=2; $i -lt $fileSubFolderCount+1; $i++) {
                    $destinationFile = Join-Path $destinationFile $fileSubFolder[$i]
                }
                $destinationFile = Join-Path $destinationFile $file.Name
            }
        }
        
        if ($category -eq "Diverses") {
            # Write-Output "Kategorie Diverses"
            $destinationFile = Join-Path $destinationCategoryPath $file.Name
        }

        if ($category -eq "Filme") {
            # Write-Output "Kategorie Filme"
            $destinationFile = Join-Path $destinationCategoryPath (Join-Path $destinationSubFolder $file.Name)
        }

        if ($category -eq "Musik") {
            # Write-Output "Kategorie Musik"
            if ($fileSubFolder[0] -eq "Verschiedene Dateien" -and $fileSubFolderCount -gt 1) {
                $destinationFile = Join-Path $destinationCategoryPath $fileSubFolder[1]
                for ($i=2; $i -lt $fileSubFolderCount+1; $i++) {
                    $destinationFile = Join-Path $destinationFile $fileSubFolder[$i]
                }
                $destinationFile = Join-Path $destinationFile $file.Name
                
            } else {
                $destinationFile = Join-Path $destinationCategoryPath (Join-Path $destinationSubFolder $file.Name)
            }
        }

        if ($category -eq "Programme") {
            # Write-Output "Kategorie Programme"
            if ($fileSubFolder[0] -eq "Verschiedene Dateien" -and $fileSubFolderCount -gt 1) {
                $destinationFile = Join-Path $destinationCategoryPath $fileSubFolder[1]
                for ($i=2; $i -lt $fileSubFolderCount+1; $i++) {
                    $destinationFile = Join-Path $destinationFile $fileSubFolder[$i]
                }
                $destinationFile = Join-Path $destinationFile $file.Name
            } else {
                $destinationFile = Join-Path $destinationCategoryPath (Join-Path $destinationSubFolder $file.Name)
            }
        }

        if ($category -eq "Serien") {
            # Write-Output "Kategorie Serien"
            $destinationFile = Join-Path $destinationCategoryPath $file.Name
        }

        if ($category -eq "Video") {
            # Write-Output "Kategorie Video"
            if ($fileSubFolder -eq "file" -and $fileSubFolderCount -gt 1) {
                $destinationFile = Join-Path $destinationCategoryPath ($fileSubFolder[0] + $file.Extension)
            } else {
                $destinationFile = Join-Path $destinationCategoryPath $file.Name
            }
        }
    } else { $destinationFile = Join-Path $destinationCategoryPath $file.Name }

    # Create the folder for the file:
    New-Item (Split-Path $destinationFile -Parent) -ItemType Directory -Force | Out-Null

    # Check if file already exists:
    $num=1
    while ((Test-Path -literalPath $destinationFile) -and (Test-Path -literalPath $file)) {   
        # Compare the files if they are the same
        if ((Get-FileHash $destinationFile).Hash -eq (Get-FileHash $file).Hash) {
            Remove-Item -LiteralPath $file -Force # If they are the same delete the source file
        } else {
            # If they are not the same add a suffix to it
            $destinationFile = Join-Path $destinationCategoryPath ($file.BaseName + "_$num" + $file.Extension)
            $num+=1
        }
    }
    if (Test-Path -literalPath $file) {
        if ($whatif) {
            $movedFile = Move-Item -LiteralPath $file.FullName -Destination $destinationFile -passThru -whatif
        } else {
            $movedFile = Move-Item -LiteralPath $file.FullName -Destination $destinationFile -passThru
        }
    }
    if ($passThru) { 
        Write-Output $movedFile 
        Write-Log "$file > $movedFile" 
    }
}

# Delete all files not moved and in our filter
$extensionDeleteFilter = @($extensionMappingsToDelete |% {"*$_" })
$filesToDelete = Get-ChildItem -Path $path -Recurse -Include $extensionDeleteFilter |? { $rootFolder -notcontains (($_ -split "\\")[2]) }

Write-Log "Deleted Files:"
foreach ($file in $filesToDelete) 
{
    if (Test-Path -literalPath $file) {
        $deletedFile = Remove-Item -LiteralPath $file.FullName -Force
    }
    if ($passThru) { 
        Write-Output $deletedFile 
        Write-Log "$deletedFile"
    }
}

# Delete all empty folders
$foldersToDelete = @()

Write-Log "Deleted Folders:"
foreach ($folder in (Get-ChildItem -LiteralPath $path -Recurse |? { $_.PSIsContainer -and $rootFolder -notcontains (($_ -split "\\")[2]) }))
{
    $foldersToDelete += New-Object PSObject -Property @{
        Object = $folder
        Depth = ($folder.FullName -split "\\").count
    }
}
$foldersToDelete = $foldersToDelete | Sort Depth -Descending

foreach ($folder in $foldersToDelete)
{
    If ($folder.Object.GetFileSystemInfos().count -eq 0) 
    { 
        $deletedFolder = Remove-Item -LiteralPath $folder.Object.FullName -Force
    }
    if ($passThru) { 
        Write-Output $deletedFolder 
        Write-Log "$deletedFolder"
    }
}