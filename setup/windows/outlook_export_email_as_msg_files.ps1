# Outlook Email Bulk Export to MSG Files (Outlook native format)
# MSG files open directly in Outlook and preserve all formatting

# Configuration
$ExportPath = "C:\dump_n_exported\"

# Create export directory if it doesn't exist
if (!(Test-Path $ExportPath)) {
    New-Item -ItemType Directory -Path $ExportPath -Force
    Write-Host "Created export directory: $ExportPath"
}

# Function to list all folders recursively
function List-OutlookFolders {
    param($FolderCollection, $Indent = "")
    
    $FolderList = @()
    
    foreach ($Folder in $FolderCollection) {
        # Only show mail folders (not calendar, contacts, etc.)
        if ($Folder.DefaultItemType -eq 0) {  # 0 = olMailItem
            $FolderInfo = [PSCustomObject]@{
                Name = "$Indent$($Folder.Name)"
                FullName = $Folder.FolderPath
                ItemCount = $Folder.Items.Count
                FolderObject = $Folder
            }
            $FolderList += $FolderInfo
            
            # Recursively get subfolders
            if ($Folder.Folders.Count -gt 0) {
                $FolderList += List-OutlookFolders -FolderCollection $Folder.Folders -Indent "$Indent  "
            }
        }
    }
    
    return $FolderList
}

try {
    # Connect to Outlook
    Write-Host "Connecting to Outlook..."
    $Outlook = New-Object -ComObject Outlook.Application
    $Namespace = $Outlook.GetNamespace("MAPI")
    
    Write-Host "`n=== AVAILABLE EMAIL FOLDERS ==="
    Write-Host "Scanning all accounts and folders..."
    
    $AllFolders = @()
    $FolderIndex = 1
    
    # Get folders from all accounts
    foreach ($Store in $Namespace.Stores) {
        if ($Store.ExchangeStoreType -eq 0 -or $Store.ExchangeStoreType -eq 3) {  # Primary or Additional mailboxes
            Write-Host "`nAccount: $($Store.DisplayName)"
            Write-Host ("=" * 50)
            
            $AccountFolders = List-OutlookFolders -FolderCollection $Store.GetRootFolder().Folders
            
            foreach ($Folder in $AccountFolders) {
                Write-Host "[$FolderIndex] $($Folder.Name) ($($Folder.ItemCount) items)"
                $Folder | Add-Member -NotePropertyName "Index" -NotePropertyValue $FolderIndex
                $AllFolders += $Folder
                $FolderIndex++
            }
        }
    }
    
    Write-Host "`n" + ("=" * 60)
    Write-Host "Enter the folder number(s) you want to export:"
    Write-Host "- Single folder: 5"
    Write-Host "- Multiple folders: 2,5,8"
    Write-Host "- Range: 3-7"
    Write-Host "- Combined: 1,3-5,8"
    Write-Host "- Type 'q' to quit"
    Write-Host ("=" * 60)
    
    $UserInput = Read-Host "Your selection"
    
    if ($UserInput.ToLower() -eq 'q') {
        Write-Host "Export cancelled."
        return
    }
    
    # Parse user input
    $SelectedIndices = @()
    $InputParts = $UserInput -split ','
    
    foreach ($Part in $InputParts) {
        $Part = $Part.Trim()
        if ($Part -match '(\d+)-(\d+)') {
            # Range (e.g., 3-7)
            $Start = [int]$Matches[1]
            $End = [int]$Matches[2]
            $SelectedIndices += $Start..$End
        } elseif ($Part -match '^\d+$') {
            # Single number
            $SelectedIndices += [int]$Part
        }
    }
    
    $SelectedIndices = $SelectedIndices | Sort-Object | Get-Unique
    
    Write-Host "`nSelected folders for export:"
    foreach ($Index in $SelectedIndices) {
        $SelectedFolder = $AllFolders | Where-Object { $_.Index -eq $Index }
        if ($SelectedFolder) {
            Write-Host "- $($SelectedFolder.Name) ($($SelectedFolder.ItemCount) items)"
        }
    }
    
    $Confirm = Read-Host "`nProceed with export? (y/n)"
    if ($Confirm.ToLower() -ne 'y') {
        Write-Host "Export cancelled."
        return
    }
    
    # Export emails from selected folders
    $TotalExported = 0
    
    foreach ($Index in $SelectedIndices) {
        $FolderToExport = $AllFolders | Where-Object { $_.Index -eq $Index }
        if (-not $FolderToExport) {
            Write-Warning "Folder index $Index not found. Skipping..."
            continue
        }
        
        $Folder = $FolderToExport.FolderObject
        Write-Host "`n" + ("=" * 60)
        Write-Host "Exporting from: $($FolderToExport.Name)"
        Write-Host "Items to export: $($Folder.Items.Count)"
        Write-Host ("=" * 60)
        
        # Create subfolder for this folder's emails
        $FolderSafeName = $Folder.Name -replace '[\\/:*?"<>|]', '_'
        $FolderExportPath = Join-Path $ExportPath $FolderSafeName
        if (!(Test-Path $FolderExportPath)) {
            New-Item -ItemType Directory -Path $FolderExportPath -Force | Out-Null
        }
        
        # Counter for progress
        $Counter = 0
        $TotalItems = $Folder.Items.Count
        $FolderExported = 0
        
        # Export each email
        foreach ($Item in $Folder.Items) {
            $Counter++
            
            # Skip non-mail items
            if ($Item.Class -eq 43) {  # 43 = olMail
                try {
                    # Create safe filename (remove invalid characters)
                    $Subject = $Item.Subject
                    if ([string]::IsNullOrEmpty($Subject)) {
                        $Subject = "No Subject"
                    }
                    
                    # Remove invalid filename characters
                    $InvalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
                    $Subject = $Subject -replace "[$InvalidChars]", "_"
                    
                    # Limit filename length
                    if ($Subject.Length -gt 100) {
                        $Subject = $Subject.Substring(0, 100)
                    }
                    
                    # Create filename with timestamp to ensure uniqueness
                    $Timestamp = $Item.ReceivedTime.ToString("yyyyMMdd_HHmmss")
                    $FileName = "$Timestamp`_$Subject.msg"
                    $FilePath = Join-Path $FolderExportPath $FileName
                    
                    # Save as .msg (Outlook native format - preserves everything)
                    $Item.SaveAs($FilePath, 3)  # 3 = olMSG format
                    
                    $FolderExported++
                    Write-Host "[$Counter/$TotalItems] Exported: $FileName"
                    
                    # Optional: Add attachment info to console
                    if ($Item.Attachments.Count -gt 0) {
                        Write-Host "   -> Contains $($Item.Attachments.Count) attachment(s)"
                    }
                    
                }
                catch {
                    Write-Warning "Failed to export item $Counter`: $($_.Exception.Message)"
                }
            }
            
            # Progress indicator every 50 items
            if ($Counter % 50 -eq 0) {
                Write-Host "Progress: $Counter/$TotalItems emails processed..."
            }
        }
        
        Write-Host "Folder '$($Folder.Name)' completed: $FolderExported emails exported"
        $TotalExported += $FolderExported
    }
    
    Write-Host "`n" + ("=" * 60)
    Write-Host "EXPORT COMPLETED!"
    Write-Host "Total emails exported: $TotalExported"
    Write-Host "Export location: $ExportPath"
    Write-Host "`nNOTE: .msg files will open directly in Outlook with full formatting"
    Write-Host ("=" * 60)
    
}
catch {
    Write-Error "Script failed: $($_.Exception.Message)"
}
finally {
    # Clean up COM objects
    if ($Outlook) {
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($Outlook) | Out-Null
    }
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}
