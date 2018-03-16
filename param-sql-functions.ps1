function New-ParamSQLConnection {
    param (
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$ConnectionString
    )

    $c = [System.Data.SqlClient.SqlConnection] $ConnectionString

    # check connection
    try {
        $c.ConnectionString += ";Connect Timeout=3"
        $c.Open()

        return $Connection
    } 
    catch   { 
        Write-Error -Message "SQL Connection Error : $($error[0].Exception.Message)" -ErrorAction Stop
        return
        
    }
    finally {
        $c.Close()
        $c.ConnectionString = $ConnectionString
    }
}

function New-ParamSQLQuery() {
[CmdletBinding(DefaultParametersetName="Select")]
Param (	
	[parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [System.Data.SqlClient.SqlConnection]$Connection,
    
    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
	[String]$Table,
	
    [parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
	[string]$Filter,
	
    # Delete
    [parameter(Mandatory=$true, ParameterSetName="Delete")]
    [switch]$DeleteMode,

    # Select
	[parameter(Mandatory=$true, ParameterSetName="Select")]
	[string[]]$SelectColumns = "*",

	# Insert
    [parameter(Mandatory=$true,  ParameterSetName="Insert")]
    [hashtable]$InsertKeyValue,

	[parameter(Mandatory=$false, ParameterSetName="Insert")] 
	[switch]$GetIDBack,

    # Update
    [parameter(Mandatory=$true, ParameterSetName="Update")]
    [hashtable]$UpdateKeyValue,

    # Custom
    [parameter(Mandatory=$true, ParameterSetName="Custom")]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$CustomFilePath,
    
    [parameter(Mandatory=$false, ParameterSetName="Custom")]
    [hashtable]$CustomReplacements
)

    Begin {
        function ConvertTo-EscapedSQL($InputObject, $SurroundChar='"') {
            $len = $InputObject.count
            $output = @()
            
            foreach ($item in $InputObject) {
                if ([string]::IsNullOrEmpty($item) -OR [string]::IsNullOrWhitespace($item)) {
                    $output += "{1}{0}{1}" -f "NULL", $SurroundChar
                }

                else {
                    $escaped = "$item" -replace "'", "''"
                    $output += "{1}{0}{1}" -f $escaped, $SurroundChar
                }
            }
            
            return $output
        }
        function Invoke-SQLQuery () {
            param(
                [parameter(Mandatory=$true)]
                [System.Data.SqlClient.SqlConnection]$Connection,

                [parameter(Mandatory=$true, ParameterSetName="Query")]
                [ValidateNotNullOrEmpty()]
                [String]$Query
            )

            $Cmd = New-Object System.Data.SqlClient.SqlCommand `
            -ArgumentList @($Query, $Connection)

            $DataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter `
            -ArgumentList @($Cmd)

            # catch syntax errors
            try {
                $DataTable = New-Object System.Data.DataTable
                $DataAdapter.Fill($DataTable) | Out-Null
                $SCRIPT:QuerySuccess = $true
            } catch {
                Write-Error -Message "Query Syntax Errror : $($Error[0].Exception.InnerException.Message)"
                return
            }

            return $DataTable

        }
        
        if ($Filter -AND $Filter -notlike "Where*") {$Filter = "WHERE $Filter"}
        $TableText = "[$($Connection.Database)].[dbo].[$Table]"
        $QueryType = $PSCmdlet.ParameterSetName

        $SCRIPT:QuerySuccess = $false
    }

    Process {
        switch ($QueryType) {
            "Insert" {
                [array]$Columns = $(ConvertTo-EscapedSQL $InsertKeyValue.Keys) -join ', '
                [array]$ColumnValues = $(ConvertTo-EscapedSQL -InputObject $InsertKeyValue.Values -SurroundChar "'") -join ', '

                $GeneratedSQLQuery = "INSERT INTO $TableText ($Columns) VALUES ($ColumnValues); SELECT SCOPE_IDENTITY() AS LastID"
            }
            "Update" {
                [array]$Columns = ConvertTo-EscapedSQL $UpdateKeyValue.Keys
                [array]$ColumnValues = ConvertTo-EscapedSQL -InputObject $UpdateKeyValue.Values -SurroundChar "'"
                
                $UpdateStatements = @()
                $len = $Columns.Count; for ($i=0; $i -lt $len; $i++) {
                    $UpdateStatements += "$($Columns[$i]) = $($ColumnValues[$i])"
                }

                $GeneratedSQLQuery = "UPDATE $TableText SET $($UpdateStatements -join ', ') $Filter"
            }
            "Delete" {
                $GeneratedSQLQuery = "DELETE FROM $TableText $Filter"
            }
            "Select" {
                $SelectColumns = $SelectColumns -join ','
                $GeneratedSQLQuery = "SELECT $SelectColumns FROM $TableText $Filter"
            }
            "Custom" {
                [string]$ImportedSQLFile = Get-Content "$CustomFilePath"
                
                if ($CustomReplacements -ne $null) { 
                    $CustomReplacements.GetEnumerator() | ForEach-Object {
                        $ImportedSQLFile = $ImportedSQLFile.Replace(
                        $($_.Key), $($_.Value))
                    }                
                }
                
                $GeneratedSQLQuery = $ImportedSQLFile
            }
        }
        
        # short back and sides?
        $GeneratedSQLQuery = $GeneratedSQLQuery.Trim()

        # let sql do its thing
        Write-Verbose "Query Type: $QueryType"
        Write-Verbose "Query: $GeneratedSQLQuery"
        $QueryResults = Invoke-SQLQuery `
            -Connection $Connection `
            -Query $GeneratedSQLQuery

    }

    End {
        if ($QueryType -eq "Insert") {
            return $($QueryResults.LastID)
        }

        elseif ($QueryType -match "Select|Custom") {
            # if q has output, return, otherwise let it drop
            if ($QueryResults) { return $QueryResults }
        }

        else {
            return $QuerySuccess
        }
    }
} 