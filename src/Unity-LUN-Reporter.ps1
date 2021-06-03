# Dot source required functions.
. "$PSScriptRoot\Get-IniFile-Function.ps1"


# Get global config parameters from config.ini.
$CONFIG = Get-IniFile "$PSScriptRoot\..\configs\Unity-LUN-Reporter-config.ini"
$USERNAME = $CONFIG.LoginCreds.username
$PASSWORD = $CONFIG.LoginCreds.password
$CUSTOMER = $CONFIG.CustomerInfo.name

$EXAMPLE_MACHINE_1 = $CONFIG.IpAddresses.IP1
$EXAMPLE_MACHINE_2 = $CONFIG.IpAddresses.IP2


# Declare other global variables.
$NEWLINE = [System.Environment]::NewLine
$DATE = Get-Date
$HTML_START = @"
<!DOCTYPE html>
<html>
<head>
  <title>
    $CUSTOMER LUN Distribution Report
  </title>

  <style>
    table {
      border-width: 1px;
      border-style: solid;
      border-color: black;
      border-collapse: collapse;
    }

    th {
      border-width: 1px;
      padding: 3px;
      border-style: solid;
      border-color: black;
      background-color: #08088A;
      color: white;
      font-size: 100%;
    }

    td {
      border-width: 1px;
      padding: 3px;
      border-style: solid;
      border-color: black;
      font-size: 100%;
    }
  </style>
</head>

<body>
<div align = center>
  <b>$CUSTOMER LUN Distribution Report<br/>$DATE</b>

  <br/><br/>
  $NEWLINE
"@
$HTML_END = @"
$NEWLINE
</div>
</body>
</html>
"@
$HTML_BREAK = $NEWLINE + $NEWLINE + "  <br/><br/>" + $NEWLINE + $NEWLINE


# Declare global functions.
function New-LUNReport {
    # New-LUNReport -Label [Site Label] -Destination [IP Address] -User [Login Username] -Pass [Login Password]
    Param (
        [Parameter(Mandatory=$true)]
        [string] $Label,
        [Parameter(Mandatory=$true)]
        [string] $Destination,
        [Parameter(Mandatory=$true)]
        [string] $User,
        [Parameter(Mandatory=$true)]
        [string] $Pass
    )

    # Get the information for the LUN report and place it in a variable.
    $UnityVMware = Write-Output y |  uemcli -d $Destination -u Local/$User -p $Pass /stor/prov/vmware/vmfs show -detail | Select-Object -Skip 4 | Out-String
    $UnityBlock = Write-Output y | uemcli -d $Destination -u Local/$User -p $Pass /stor/prov/luns/lun show -detail | Select-Object -Skip 4 | Out-String
    $UnityLuns = $UnityBlock + $UnityVMware

    # Remove numbers before each "ID" field.
    $UnityLuns = $UnityLuns -Replace "^\d+:\s+","" -Replace ($NEWLINE + "\d+:\s+(?=ID)"),($NEWLINE + "      ")

    # Move the fields we care about to their own lines to prepare for hash table conversion.
    $UnityLuns = $UnityLuns -Replace "Extreme Performance:\s*",($NEWLINE + "      Extreme Performance = ")
    $UnityLuns = $UnityLuns -Replace ", Performance:\s*",($NEWLINE + "      Performance = ")
    $UnityLuns = $UnityLuns -Replace ", Capacity:\s*",($NEWLINE + "      Capacity = ")

    # Make the "ID" field unique by placing non-whitespace characters before the ending "ID" in "Storage pool ID".
    $UnityLuns = $UnityLuns -Replace "Storage pool ID","Storage-pool-ID"

    # Split each block at their "ID" field and make each block a hash table.
    # $UnitySummary will be an array of hash tables.
    $UnitySummary = $UnityLuns -Split "(?=      ID)" |
            ForEach-Object {
                New-Object PSObject -Property  $(ConvertFrom-StringData $_)
            }

    # Make an HTML table that contains each block. Extract necessary information.
    $UnitySummary = $UnitySummary | Select-Object 'Name','Storage pool','Extreme Performance','Performance','Capacity' | Sort-Object 'Name' | ConvertTo-Html -Fragment

    # Format the HTML table.
    $UnitySummary = $UnitySummary -replace "</colgroup>","</colgroup><tr><th colspan=5>$Label Unity 400</th></tr>"

    return $UnitySummary
}


# Generate the LUN report for each site.
$ExampleMachine1UnitySummary = New-LUNReport -Label "Label 1" -Destination $EXAMPLE_MACHINE_1 -User $USERNAME -Pass $PASSWORD
$ExampleMachine2UnitySummary = New-LUNReport -Label "Label 2" -Destination $EXAMPLE_MACHINE_2 -User $USERNAME -Pass $PASSWORD

# Format and generate the LUN report in an HTML file.
$LUNReport = $HTML_START + $ExampleMachine1UnitySummary + $HTML_BREAK + $ExampleMachine2UnitySummary + $HTML_END
$LUNReport | Out-File "$PSScriptRoot\..\LUN-Report-$CUSTOMER.html"
