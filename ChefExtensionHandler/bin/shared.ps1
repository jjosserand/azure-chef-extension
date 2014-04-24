
function Chef-GetScriptDirectory
{
  $Invocation = (Get-Variable MyInvocation -Scope 1).Value
  Split-Path $Invocation.MyCommand.Path
}

$scriptDir = Chef-GetScriptDirectory

$chefExtensionRoot = [System.IO.Path]::GetFullPath("$scriptDir\\..")

# Returns a json object from json file
function Read-JsonFromFile
{
  (Get-Content $args[0]) -join "`n" | ConvertFrom-Json
}

function Get-HandlerSettingsFileName
{
  (Get-ChildItem "$chefExtensionRoot\\RuntimeSettings" -Filter *.settings | Sort-Object Name -descending | Select-Object -First 1 ).Name
}

function Get-HandlerSettingsFilePath {
  $latestSettingFile = Get-HandlerSettingsFileName
  $fileName = "$chefExtensionRoot\\RuntimeSettings\\$latestSettingFile"
  $fileName
}

function Get-HandlerEnvironmentFilePath {
  $fileName = "$chefExtensionRoot\\HandlerEnvironment.json"
  $fileName
}

# returns the handler settings read from the latest settings file
function Get-HandlerSettings
{
  $latestSettingFile = Get-HandlerSettingsFileName
  $runtimeSettingsJson = Read-JsonFromFile $chefExtensionRoot"\\RuntimeSettings\\$latestSettingFile"
  $runtimeSettingsJson.runtimeSettings[0].handlerSettings
}

function Get-BootstrapDirectory {
  "C:\\chef"
}

function Chef-AddToPath($folderPath)
{
  $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
  [Environment]::SetEnvironmentVariable("Path", "$folderPath;$currentPath", "Machine")
  $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
  [Environment]::SetEnvironmentVariable("Path", "$folderPath;$currentPath", "User")
  $currentPath = [Environment]::GetEnvironmentVariable("Path", "Process")
  [Environment]::SetEnvironmentVariable("Path", "$folderPath;$currentPath", "Process")
}

function Get-PowershellVersion {
  $PSVersionTable.PSVersion.Major
}

# write status to file N.status
function Write-ChefStatus ($operation, $statusType, $message)
{
  # the path of this file is picked up from HandlerEnvironment.json
  # the sequence is obtained from the handlerSettings file sequence
  $sequenceNumber = $json_handlerSettingsFileName.Split(".")[0]
  $statusFile = $json_statusFolder + "\\" + $sequenceNumber + ".status"

  # the status file is in json format
  $timestampUTC = (Get-Date -Format u).Replace(" ", "T")
  $formattedMessageHash = @{lang = "en-US"; message = "$message" }
  $statusHash = @{name = "Chef Extension Handler"; operation = "$operation"; status = "$statusType"; code = 0; formattedMessage = $formattedMessageHash; }

  $hash = @(@{version = "1"; timestampUTC = "$timestampUTC"; status = $statusHash})

  if ( $(Get-PowershellVersion) -ge 3) {
    ConvertTo-Json -Compress $hash -Depth 4 | Out-File -filePath $statusFile
  }
}

function Update-ChefExtensionRegistry
{
  param (
    $Path = "HKLM:\Software\Chef\AzureExtension",
    $Name = "Status",
    [Parameter(Mandatory=$True,Position=1)]
    [string]$Value
  )

  # Create registry entry, with Status=updated
  if (Test-Path -Path $Path -PathType Container) {
    New-ItemProperty -Path $Path -Force -Name $Name -Value $Value
    echo "Registry entry exists, so just updated the value"
  } else {
    New-Item -Path $Path -Force -Name $Name -Value $Value
    # New-ItemProperty additionally needed below, to work for PS v 2.0
    New-ItemProperty -Path $Path -Force -Name $Name -Value $Value
    echo "Added new registry entry and updated $Name with $Value"
  }
  $temp = (Get-ItemProperty -Path $Path).$Name
  echo "Registry entry $Path after updating: $temp"
}

function Test-ChefExtensionRegistry
{
  param (
    $Path = "HKLM:\Software\Chef\AzureExtension",
    $Name = "Status",
    $Value = "updated"
  )
  # checks if the entry with correct value in registry
  # if yes, it returns true
  If (Test-Path -Path $Path -PathType Container) {
    If ((Get-ItemProperty -Path $Path).$Name -eq $Value) {
      return $True
    } else { return $False }
  } else {
    return $False
  }
}

function Get-HandlerEnvironment {
  (Read-JsonFromFile $chefExtensionRoot"\\HandlerEnvironment.json").handlerEnvironment
}

# Reads all the json files needed and sets the fields needed
function Read-JsonFile
{
  $json_handlerSettingsFileName = Get-HandlerSettingsFileName
  $json_handlerSettings = Get-HandlerSettings
  $json_protectedSettings = $json_handlerSettings.protectedSettings
  $json_protectedSettingsCertThumbprint = $json_handlerSettings.protectedSettingsCertThumbprint
  $json_client_rb = $json_handlerSettings.publicSettings.client_rb
  $json_runlist = $json_handlerSettings.publicSettings.runList

  $json_handlerEnvironment = Get-HandlerEnvironment
  $json_chefLogFolder = $json_handlerEnvironment.logFolder
  $json_statusFolder = $json_handlerEnvironment.statusFolder
  $json_heartbeatFile = $json_handlerEnvironment.heartbeatFile

  return  $json_handlerSettingsFileName, $json_handlerSettings, $json_protectedSettings,  $json_protectedSettingsCertThumbprint, $json_client_rb , $json_runlist, $json_chefLogFolder, $json_statusFolder, $json_heartbeatFile
}

function Get-JsonValueUsingRuby($file) {
  $keys = $args -join "','"
  ruby.exe -e "require 'chef/azure/helpers/parse_json'; value_from_json_file '$file', '$keys'"
}

# Reads all the json files and sets vars using ruby code
function Read-JsonFileUsingRuby
{
  $json_handlerSettingsFileName = Get-HandlerSettingsFilePath

  $json_handlerSettings = Get-JsonValueUsingRuby $json_handlerSettingsFileName "runtimeSettings" "0" "handlerSettings"

  $json_handlerProtectedSettings = Get-JsonValueUsingRuby $json_handlerSettingsFileName "runtimeSettings" "0" "handlerSettings" "protectedSettings"

  $json_handlerProtectedSettingsCertThumbprint = Get-JsonValueUsingRuby $json_handlerSettingsFileName "runtimeSettings" "0" "handlerSettings" "protectedSettingsCertThumbprint"

  $json_handlerPublicSettingsClient_rb = Get-JsonValueUsingRuby $json_handlerSettingsFileName "runtimeSettings" "0" "handlerSettings" "publicSettings" "client_rb"

  $json_handlerPublicSettingsRunlist = Get-JsonValueUsingRuby $json_handlerSettingsFileName "runtimeSettings" "0" "handlerSettings" "publicSettings" "runList"

  $json_handlerEnvironmentFileName = Get-HandlerEnvironmentFilePath

  $json_handlerChefLogFolder = Get-JsonValueUsingRuby $json_handlerEnvironmentFileName "handlerEnvironment" "logFolder"

  $json_handlerStatusFolder = Get-JsonValueUsingRuby $json_handlerEnvironmentFileName "handlerEnvironment" "statusFolder"

  $json_handlerHeartbeatFile = Get-JsonValueUsingRuby $json_handlerEnvironmentFileName "handlerEnvironment" "heartbeatFile"

  return $json_handlerSettingsFileName, $json_handlerSettings, $json_handlerProtectedSettings, $json_handlerProtectedSettingsCertThumbprint, $json_handlerPublicSettingsClient_rb, $json_handlerPublicSettingsRunlist, $json_handlerChefLogFolder, $json_handlerStatusFolder, $json_handlerHeartbeatFile
}