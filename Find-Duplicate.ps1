
Function Find-Duplicates {
    <#

    #>
    [CmdletBinding(DefaultParameterSetName = 'List')]
    Param (
        [Parameter(Mandatory = $True)][System.String]$Target,

        [Parameter(Mandatory = $True,  ParameterSetName = 'Move')][System.Management.Automation.SwitchParameter]$Move,
        [Parameter(Mandatory = $True,  ParameterSetName = 'Delete')][System.Management.Automation.SwitchParameter]$Delete,
        [Parameter(Mandatory = $False, ParameterSetName = 'List')][System.String]$OutPath
    )

    If (-Not (Test-Path -Path $Target)) {Throw [System.Management.Automation.ItemNotFoundException]"The path '$Target' does not exist."}

    [System.String]$HyphenLine = -Join ('-' * $Host.UI.RawUI.BufferSize.Width)

    Write-Host 'Searching for duplicates...'
    Write-Host $HyphenLine

    Write-Host 'Collecting files...'
    [System.Object[]]$FilesInTarget = Get-ChildItem -Path $Target -File -Recurse -ErrorAction Continue

    [System.Int32]$Iteration = 0
    [System.Collections.Hashtable]$HashProgress = Update-SplatObject @{} -A ' Hashing files...' -S 'Preparing...' -P 0

    [System.Object[]]$FileHashes = ForEach ($File in $FilesInTarget) {
        $Iteration++

        $HashProgress = Update-SplatObject $HashProgress -S $File.FullName -P (($Iteration / $FilesInTarget.Count) * 100)

        Write-Progress @HashProgress

        Get-FileHash -LiteralPath $File.FullName
    }

    $HashProgress = Update-SplatObject $HashProgress -S 'Done' -P 100 -C
    Write-Progress @HashProgress

    Write-Host -NoNewline 'Looking for duplicates... '
    $Duplicates = $FileHashes | Group-Object -Property Hash | Where-Object Count -GT 1
    If ($Duplicates.Count -lt 1) {Write-Host -ForegroundColor Green 'No duplicates found.'}
    Else {
        Write-Host -ForegroundColor Yellow "$($Duplicates.Count) duplicates found."
        $Result    = ForEach ($Dupe in $Duplicates) {$Dupe.Group | Select-Object -Property Path, Hash}
        $Date      = Get-Date -Format "yyyy.MM.dd"
        $MoveItems = $Result | Out-GridView -Title "Select files (CTRL for multiple) and press OK. Selected files will be moved to C:\Duplicates_$date" -PassThru
        If ($MoveItems) {
            New-Item -ItemType Directory -Path "$($env:SystemDrive)\Duplicates_$date" -Force
            Move-Item $MoveItems.Path -Destination "$($env:SystemDrive)\Duplicates_$date" -Force
            Write-Host 'Operation complete'
            Start-Process "$($env:SystemDrive)\Duplicates_$date"
        }
        Else {Write-Host 'Aborted.'}
    }
}
Function Format-StatusString {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][System.String]$Status,
        [System.Double]$Completion = 0
    )
    $Status = "  $("{0:0.00}" -f $Completion)% - $Status"
    If ($Status.Length -gt 98) {$Status = $Status.Substring(0, 94) + '...'}
    Return [System.String]($Status.PadRight(98))
}
Function Update-SplatObject {
    <#
    .INPUTS
    [-InputObject <System.Collections.Hashtable>]
    [-Name <System.String>]
    [[-Activity <System.String>][-Status <System.String>][-Progress <System.Double>][-Complete]]
    [[-R <System.Char[]>]]
    [[-Remove <System.String[]]]

    .OUTPUTS
    [System.Collections.Hashtable]

    .PARAMETER InputObject
    Hashtable to process

    .PARAMETER Activity
    Activity string

    .PARAMETER Status
    Status string

    .PARAMETER Progress
    Progress percentage

    .PARAMETER Complete
    Completes Write-Progress

    .PARAMETER R
    Removes keys

    .PARAMETER Remove
    Removes keys
    #>
    [CmdletBinding(DefaultParameterSetName = 'Add')]
    Param (
        # PARAM: InputObject {
            [Parameter(
                ParameterSetName = 'Add',
                Mandatory        = $True,
                Position         = 1
            )]
            [Parameter(
                ParameterSetName = 'Remove1',
                Mandatory        = $True,
                Position         = 1
            )]
            [Parameter(
                ParameterSetName = 'Remove2',
                Mandatory        = $True,
                Position         = 1
            )]
            [Alias('I')]
            [System.Collections.Hashtable]$InputObject,
        # }

        # PARAM: Create {
            [Parameter(
                ParameterSetName = 'Create',
                Mandatory        = $True,
                Position         = 1
            )]
            [System.Management.Automation.SwitchParameter]$Create,
        # }
        
        # PARAM: Remove {
            [Parameter(
                ParameterSetName = 'Remove1',
                Mandatory        = $True,
                Position         = 2
            )]
            [ValidateSet('Activity', 'Status', 'Progress', 'Complete', 'ID', 'ParentID')]
            [ValidateCount(1, 6)]
            [ValidateScript({
                [System.Boolean](-Not (Compare-Object -ReferenceObject $_ -DifferenceObject ($_ | Select-Object -Unique)))
            })]
            [System.String[]]$Remove,
        # }

        # PARAM: R {
            [Parameter(
                ParameterSetName = 'Remove2',
                Mandatory        = $True,
                Position         = 2
            )]
            [ValidateSet('A', 'S', 'P', 'C', 'ID', 'PID')]
            [ValidateCount(1, 6)]
            [ValidateScript({
                [System.Boolean](-Not (Compare-Object -ReferenceObject $_ -DifferenceObject ($_ | Select-Object -Unique)))
            })]
            [System.String[]]$R,
        # }

        # PARAM: Activity {
            [Parameter(
                ParameterSetName = 'Add',
                Mandatory        = $False,
                Position         = 2
            )]
            [Parameter(
                ParameterSetName = 'Create',
                Mandatory        = $False,
                Position         = 2
            )]
            [Alias('A')]
            [System.String]$Activity,
        # }

        # PARAM: Status {
            [Parameter(
                ParameterSetName = 'Add',
                Mandatory        = $False,
                Position         = 3
            )]
            [Parameter(
                ParameterSetName = 'Create',
                Mandatory        = $False,
                Position         = 3
            )]
            [Alias('S')]
            [System.String]$Status,
        # }

        # PARAM: Progress {
            [Parameter(
                ParameterSetName = 'Add',
                Mandatory        = $False,
                Position         = 4
            )]
            [Parameter(
                ParameterSetName = 'Create',
                Mandatory        = $False,
                Position         = 4
            )]
            [Alias('P')]
            [System.Double]$Progress,
        # }

        # PARAM: Complete {
            [Parameter(
                ParameterSetName = 'Add',
                Mandatory        = $False,
                Position         = 5
            )]
            [Parameter(
                ParameterSetName = 'Create',
                Mandatory        = $False,
                Position         = 5
            )]
            [Alias('C')]
            [System.Management.Automation.SwitchParameter]$Complete,
        # }

        # PARAM: ID {
            [Parameter(
                ParameterSetName = 'Add',
                Mandatory        = $False,
                Position         = 6
            )]
            [Parameter(
                ParameterSetName = 'Create',
                Mandatory        = $False,
                Position         = 6
            )]
            [System.Int32]$ID,
        # }

        # PARAM: ParentID {
            [Parameter(
                ParameterSetName = 'Add',
                Mandatory        = $False,
                Position         = 7
            )]
            [Parameter(
                ParameterSetName = 'Create',
                Mandatory        = $False,
                Position         = 7
            )]
            [Alias('PID')]
            [System.Int32]$ParentID
        # }
    ) # Param

    If ($Create) {[System.Collections.Hashtable]$InputObject = @{}}
    If ($R)      {[System.String[]]$Remove = ForEach ($Item in $R) {$Item}}
    If ($Remove) {ForEach ($Item in $Remove) {Switch ($Item) {
        {$_ -Match '(?i)A(ctivity)?'} {$InputObject.Remove('Activity')}
        {$_ -Match '(?i)S(tatus)?'}   {$InputObject.Remove('Status')}
        {$_ -Match '(?i)P(rogress)?'} {$InputObject.Remove('PercentComplete')}
        {$_ -Match '(?i)C(omplete)?'} {$InputObject.Remove('Completed')}
        {$_ -Match '(?i)ID'}          {$InputObject.Remove('Id')}
        {$_ -Match '(?i)P(arent)?ID'} {$InputObject.Remove('ParentId')}
    }}}
    Else {
        If ($Activity) {$InputObject['Activity'] = $Activity}
        If ($Status)   {
            [System.Double]$ProgressSubstitute = If ($Progress) {$Progress} ElseIf ($InputObject.PercentComplete) {$InputObject.PercentComplete} Else {0}
            $InputObject['Status']             = (Format-StatusString -Status $Status.Replace("$($Target)\", '') -Completion $ProgressSubstitute)
        }
        If ($Progress) {
            $InputObject['PercentComplete'] = $Progress
            If ($InputObject.Status -And -Not $Status) {
                $InputObject['Status'] = (Format-StatusString -Status ($InputObject.Status -Split '-', 2)[1].Substring(1) -Completion $Progress)
            }
        }
        If ($Complete) {$InputObject['Completed'] = $True}
        If ($ID)       {$InputObject['Id']        = $ID}
        If ($ParentID) {$InputObject['ParentId']  = $ParentID}
    }
    Return $InputObject
}